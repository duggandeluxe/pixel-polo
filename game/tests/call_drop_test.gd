extends RefCounted
## CALL DROP (FormationBar): your defence's one button, on the match screen.
##   godot --headless --path game -- --test call_drop
## One button replaces PRESS | M-DROP; it calls Coaching's drop, whichever it is, once a
## possession, one way; a new possession brings it back up; a 6 on 5 takes it off the screen,
## called or not, and the exclusion's own defence runs; even again, it's back, up.

const DT := 1.0 / 60.0
const F := DefenseFormation.F

var r   # the test runner (check)

func run(runner) -> void:
	r = runner
	print("call drop: the button")
	var teams: Array = r._teams()
	Game.match_cfg = {"us": teams[0], "them": teams[1], "seed": 91, "minutes": 2.0, "drop": F.FIVE_DROP}
	Game.goto("match", Game.match_cfg)
	await r.get_tree().process_frame
	var ms = Game.current_screen
	var flow: MatchFlow = ms.flow
	await _defend(ms)
	var p := flow.play
	r.check(ms.fbar.rects.size() == 1 and FormationBar.shown(flow), "1/2: one button while you defend")
	var drawn := await _drawn(ms)
	r.check(drawn.has("CALL DROP") and not drawn.has("PRESS") and not drawn.has("M-DROP") and not drawn.has("5 DROP"),
		"1/2: it reads CALL DROP; no PRESS, no M-DROP")
	r.check(p.formation == F.PRESS and not p.formation_locked and not FormationBar.called(p), "a possession starts in the normal defence, the button up")

	# the call, and a second tap
	var at: Vector2 = ms.fbar.rects[0].get_center()
	r.check(ms.fbar.press(at, flow), "3: the tap is the button's")
	r.check(p.formation_locked and (p.formation == F.FIVE_DROP or p.drop_pending == F.FIVE_DROP), "3: it calls Coaching's drop (5 DROP)")
	for i in 30:
		ms._process(DT)
	r.check(ms.fbar.press(at, flow) and FormationBar.called(p) and p.formation_locked, "4/5: pressed again: still called, not a toggle")
	r.check(p.formation == F.FIVE_DROP or p.drop_pending == F.FIVE_DROP, "5/6: ...and still 5 DROP")
	r.check(FormationBar.shown(flow), "6: still up, pressed, for the possession")

	# an ordinary foul in the same possession: the call stands
	if not p.over and p.holder != null:
		p._ordinary_foul(p.holder, p.defenders[1])
		ms._process(DT)
		r.check(p == flow.play and FormationBar.called(p) and p.formation_locked, "7: an ordinary foul doesn't reset the call")

	# a 6 on 5, called: gone, no other button
	_exclude(p)
	ms._process(DT)
	r.check(not FormationBar.shown(flow), "8/9: an exclusion takes the called button off the screen")
	drawn = await _drawn(ms)
	r.check(not drawn.has("CALL DROP") and not drawn.has("PRESS") and not drawn.has("M-DROP") and not drawn.has("6-ON-5") and not drawn.has("5 DROP"),
		"10: no defensive button at all in the 6 on 5")
	r.check(not ms.fbar.press(at, flow) and not flow.select_formation(flow.drop), "no call in the 6 on 5, by tap or otherwise")
	r.check(not DefenseFormation.active(p), "11: the exclusion's own defence is on, not the drop")
	# even again, still their ball: back, up, in the normal defence
	p.man_up = 0.0
	p._end_man_up()
	ms._process(DT)
	r.check(FormationBar.shown(flow) and not FormationBar.called(p) and p.formation == F.PRESS and not p.formation_locked,
		"12: even again: CALL DROP's back, up, the normal defence on")
	r.check(ms.fbar.press(at, flow) and p.formation_locked, "12: ...and it can be called again")

	# a 6 on 5, not called
	await _defend(ms)
	p = flow.play
	r.check(FormationBar.shown(flow) and not FormationBar.called(p), "7: a new possession: the button's up again")
	_exclude(p)
	ms._process(DT)
	r.check(not FormationBar.shown(flow), "9: the exclusion takes the uncalled button off too")
	r.check(not ms.fbar.press(at, flow) and not p.formation_locked, "...and nothing calls it in the meantime")

	# each of Coaching's drops, never a hardcoded one
	for f in DefenseFormation.DROPS:
		flow.drop = f
		await _defend(ms)
		Play.instant_drops = true
		ms.fbar.press(at, flow)
		Play.instant_drops = false
		r.check(flow.play.formation == f and flow.play.formation_locked, "3: CALL DROP calls %s when it's the gameplan" % DefenseFormation.NAMES[f])
		drawn = await _drawn(ms)
		r.check(drawn.has("CALL DROP") and not drawn.has(DefenseFormation.NAMES[f]), "the label stays CALL DROP (%s)" % DefenseFormation.NAMES[f])

	# SIM and back
	await _defend(ms)
	flow.set_sim(true)
	ms.sim = true
	drawn = await _drawn(ms)
	r.check(not drawn.has("CALL DROP"), "15: SIM plays your defence: no button")
	flow.set_sim(false)
	ms.sim = false
	drawn = await _drawn(ms)
	r.check(drawn.has("CALL DROP") and FormationBar.shown(flow), "15: SIM off: the button's yours again")

	# your attack: no button
	flow.play._turnover(flow.play.defenders[1], "STOLEN!", "steal")
	flow.defense_done()
	ms._process(DT)
	r.check(not FormationBar.shown(flow), "not on your attack")
	Game.goto("title")
	await r.get_tree().process_frame

## A fresh possession of theirs, laid out.
func _defend(ms) -> void:
	ms.flow._start_defense(Play.Kind.HALF_COURT)
	ms._process(DT)
	await r.get_tree().process_frame
	var size: Vector2 = ms.get_viewport_rect().size
	ms.fbar.layout(size, Vector2.ZERO, 3.0 + Hud.tag_parts(ms.flow.play.keeper.player).size.x + 4.0)

func _exclude(p: Play) -> void:
	p._exclusion(p.defenders[3], p.attackers[3])

## The words drawn on the next frame.
func _drawn(ms) -> Array:
	UI.drawn_log = []
	ms.canvas.queue_redraw()
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	var d: Array = UI.drawn_log
	UI.drawn_log = null
	return d

## The button's looks, up, called (mid-flash and settled) and in a 6 on 5:
##   godot --path game --resolution 480x270 -- --test call_drop_png <dir>
static func shots(runner, dir: String) -> void:
	var t = new()
	t.r = runner
	var teams: Array = runner._teams()
	Game.goto("match", {"us": teams[0], "them": teams[1], "seed": 91, "minutes": 2.0, "drop": F.M_DROP})
	await runner.get_tree().process_frame
	var ms = Game.current_screen
	var save := func(name: String) -> void:
		ms.canvas.queue_redraw()
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	ms.flow._start_defense(Play.Kind.HALF_COURT)
	for i in 20:
		await runner.get_tree().process_frame
	await save.call("call_drop_up")
	Play.instant_drops = true
	ms.fbar.press(ms.fbar.rects[0].get_center(), ms.flow)
	Play.instant_drops = false
	await runner.get_tree().process_frame
	await save.call("call_drop_flash")
	await runner.get_tree().create_timer(0.6).timeout   # (past the flash, in real time)
	await save.call("call_drop_called")
	ms.flow.play._exclusion(ms.flow.play.defenders[3], ms.flow.play.attackers[3])
	for i in 10:
		await runner.get_tree().process_frame
	await save.call("call_drop_six_on_five")
	Game.goto("title")
	await runner.get_tree().process_frame
