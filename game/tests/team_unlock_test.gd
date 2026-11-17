extends RefCounted
## THE ROAD TO GLORY's unlock show (TeamUnlock, through Game.achievement_dialog):
##   godot --headless --path game -- --test team_unlock
##   godot --path game --resolution 960x540 -- --test team_unlock_png <dir>   (frames: needs a window)

var r

func run(runner) -> void:
	r = runner
	print("team_unlock")
	var tree: SceneTree = r.get_tree()
	Game.progress = Progression.fresh()
	var closed := [0]
	for a in Progression.ACHIEVEMENTS:
		var n: int = Game.progress.schools_in_tier(int(a.tier)).size()
		var s: TeamUnlock = Game.achievement_dialog({"type": "achievement", "id": a.id, "title": a.title, "count": n}, func(): closed[0] += 1)
		await tree.process_frame
		var texts: Array = s.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
		r.check(s.ids.size() == n and s.ids.all(func(id): return Game.progress.tier_of(id) == int(a.tier)), "U1: %s shows its tier's %d schools" % [a.id, n])
		r.check("ACHIEVEMENT UNLOCKED!" in texts and String(a.title) in texts and ("%d NEW PROGRAMS AVAILABLE!" % n) in texts, "U2: %s: the headline, title and count" % a.id)
		r.check(s.t >= s.t_end, "U3: with motion off it opens at its end")
		r.check(not Game.progress.done.has(String(a.id)), "U4: showing it awards nothing")
		var ok: Button = r._find_button(s, "OK")
		ok.pressed.emit()
		ok.pressed.emit()
		await tree.process_frame
		r.check(not is_instance_valid(s) or s.is_queued_for_deletion(), "U5: OK closes it")
	r.check(closed[0] == Progression.ACHIEVEMENTS.size(), "U5: done runs once per close (%d)" % closed[0])
	# the preview: each tier in turn, nothing saved
	var seen := []
	for _i in 4:
		var p := TeamUnlock.preview()
		seen.append(p._tier())
		p._close()
	seen.sort()
	r.check(seen == [2, 3, 4, 5] and Game.progress.done.is_empty(), "U6: the preview shows every tier, awards nothing %s" % str(seen))

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Game.progress = Progression.fresh()
	Game.goto("title")
	await tree.create_timer(0.4).timeout
	var a: Dictionary = Progression.achievement_for_tier(3)
	var s: TeamUnlock = TeamUnlock.play(Game.overlay, {"type": "achievement", "id": a.id, "title": a.title, "count": 7}, Callable())
	s._motion = true
	s._fired.clear()
	s.t = 0.0
	s.set_process(false)
	var times := [["tu_1_slam", 0.3], ["tu_2_land", 0.42], ["tu_3_cards", 1.2], ["tu_4_rattle", 1.5], ["tu_5_open1", 1.65],
		["tu_6_open4", s.T_LOCKS + 3 * s.LOCK_STEP + 0.08], ["tu_7_final", s.t_final + 0.1], ["tu_8_end", s.t_end + 0.5]]
	for shot in times:
		while s.t < float(shot[1]) and s.t < s.t_end:
			s._process(1.0 / 60.0)
		if s.t >= s.t_end:
			for _k in 30:
				s._process(1.0 / 60.0)
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(String(shot[0]) + ".png"))
		print("  shot ", shot[0])
	s._close()
