extends RefCounted
## INJURY ACTIVE: ADJUST PRACTICE?: while anyone on your roster is injured, the hub's TRAINING
## button gets a red banner (a tap opens Training; nothing is changed). Opening Training or picking
## RECOVERY answers it for the week; next week it's back if anyone's still hurt. It goes once
## everyone's healed, and sits beside NEW RECRUITS AVAILABLE (on COACHING)
## without the two overlapping.
##   godot --headless --path game -- --test injury_notice
##   godot --path game --resolution 480x270 -- --test injury_notice_png <outdir>

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("injury notice")
	Store.reset_for_tests()
	await _hub()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _career(seed_value: int = 90) -> Career:
	var c := Career.new_game("GWU", "A", "B", seed_value)
	c.queue.clear()
	c.hot_tip = true
	Game.career = c
	for p in c.team().roster:
		if p.is_injured():
			Development.heal(p)
	return c

func _frames(n: int = 3) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _nav() -> Control:
	await _frames()
	return Game.current_screen.find_child("Nav_training", true, false)

func _hub() -> void:
	var c := _career()
	Game.goto("hub")
	var nav := await _nav()
	r.check(nav != null and nav.find_child("InjuryNotice", true, false) == null, "no injuries: no notice")
	var size_before := nav.size if nav != null else Vector2.ZERO
	var a: PoloPlayer = c.team().roster[0]
	var b: PoloPlayer = c.team().roster[1]
	Development.injure(a, RandomNumberGenerator.new(), "minor")
	Development.injure(b, RandomNumberGenerator.new(), "minor")
	var training := c.training.duplicate()
	var inj := [a.inj_type, b.inj_type]
	Game.goto("hub")
	nav = await _nav()
	var notice: Control = nav.find_child("InjuryNotice", true, false) if nav != null else null
	r.check(notice != null, "an injury: the notice on TRAINING")
	if notice == null:
		return
	r.check(notice.get_global_rect().end.y <= nav.get_global_rect().position.y, "it sits above the button")
	r.check(notice.mouse_filter != Control.MOUSE_FILTER_IGNORE and notice is BaseButton, "it takes a tap")
	r.check(nav.size == size_before, "COACHING's size is unchanged")
	(notice as BaseButton).pressed.emit()
	await _frames()
	r.check(Game.current_name == "training", "a tap opens Training (%s)" % Game.current_name)
	r.check(c.training == training and a.inj_type == inj[0] and b.inj_type == inj[1], "nothing changed: training and injuries as they were")
	Game.goto("hub")
	nav = await _nav()
	r.check(nav.find_child("InjuryNotice", true, false) == null, "back from Training: answered for the week, gone")
	# a new week, still injured: back
	c.week += 1
	Game.goto("hub")
	nav = await _nav()
	r.check(nav.find_child("InjuryNotice", true, false) != null, "next week, still injured: shown again")
	# the TRAINING button itself answers it too
	(nav as BaseButton).pressed.emit()
	await _frames()
	Game.goto("hub")
	nav = await _nav()
	r.check(nav.find_child("InjuryNotice", true, false) == null, "TRAINING button opened: gone")
	# RECOVERY as the focus: gone, even in a fresh week
	c.week += 1
	c.training.focus = "recovery"
	Game.goto("hub")
	nav = await _nav()
	r.check(nav.find_child("InjuryNotice", true, false) == null, "RECOVERY selected: gone")
	c.training.focus = "balanced"
	# with NEW RECRUITS AVAILABLE too (on COACHING): side by side, no overlap
	c.new_recruits = true
	Game.goto("hub")
	nav = await _nav()
	notice = nav.find_child("InjuryNotice", true, false)
	var coach: Control = Game.current_screen.find_child("Nav_coaching", true, false)
	var rec: Control = coach.find_child("RecruitsNotice", true, false)
	r.check(notice != null and rec != null, "both notices at once")
	if notice != null and rec != null:
		var ir := notice.get_global_rect()
		var rr := rec.get_global_rect()
		r.check(not ir.intersects(rr), "they don't overlap")
		r.check(ir.end.x <= rr.position.x and ir.position.x >= 0.0, "injury banner left of the recruits banner, on screen")
		var tip := ir.position.x + floorf(ir.size.x * 0.5) + float(notice.get_meta("notch_dx", 0.0))
		var nr := nav.get_global_rect()
		r.check(tip > nr.position.x and tip < nr.end.x, "its notch still points at TRAINING")
		r.check(ir.end.y <= nr.position.y and rr.end.y <= nr.position.y, "both above the nav")
		var rtip := rr.position.x + floorf(rr.size.x * 0.5) - float(rec.get_meta("notch_dx", 0.0))
		var cr := coach.get_global_rect()
		r.check(rtip > cr.position.x and rtip < cr.end.x, "the recruits notch still points at COACHING")
		# mid pop-in (the recruits banner scaled down about its notch): re-spacing still clears it
		rec.scale = Vector2(0.4, 0.4)
		Deck.nav_notices_apart(notice, rec)
		rec.scale = Vector2.ONE
		r.check(not notice.get_global_rect().intersects(rec.get_global_rect()), "spaced mid pop-in: still no overlap")
		r.check(rec.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the recruits banner still passes taps through")
	c.new_recruits = false
	# one healed: still shown; both healed: gone
	Development.heal(a)
	Game.goto("hub")
	nav = await _nav()
	r.check(nav.find_child("InjuryNotice", true, false) != null, "one still injured: still shown")
	Development.heal(b)
	Game.goto("hub")
	nav = await _nav()
	r.check(nav.find_child("InjuryNotice", true, false) == null, "everyone healed: gone")
	r.check(nav.size == size_before, "...and COACHING's size never moved")

# ------------------------------------------------------------------ screenshots
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("GWU", "Sam", "Rivera", 31)
	c.queue.clear()
	c.hot_tip = true
	Game.career = c
	Development.injure(c.team().roster[0], RandomNumberGenerator.new(), "minor")
	for both in [false, true]:
		c.new_recruits = both
		Game.goto("hub")
		await tree.create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		var nm := "inj_hub_both.png" if both else "inj_hub.png"
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(nm))
		print("  shot ", nm)
