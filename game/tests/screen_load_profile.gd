extends RefCounted
## How long each screen freezes the game when it opens: script load, new()+setup(), _ready()
## (add_child), and the first frame drawn after it. Cold (first open) and warm (second open).
##   godot --path game -- --test screen_profile          (needs a window for real draw times)
##   godot --path game -- --test screen_profile warm     (after the ScreenWarmup, as the game runs:
##       also the threaded dynasty setup and PICK YOUR SCHOOL's staggered cards; add main_thread
##       for the web build's warm-up, nosetup / nostagger to leave those out)
##   godot --headless --path game -- --test starters_memo   (PoloTeam.starters() remembered == afresh)

const SCREENS := ["hub", "more", "roster", "training", "facilities", "recruiting", "schedule", "top20",
	"store", "visual_shop", "records", "conference", "news", "program", "coaching", "awards",
	"trophy_room", "careers", "settings", "quick_match", "title", "new_career", "matchup"]

static func run(runner: Node, warm := false) -> void:
	var tree := runner.get_tree()
	Store.reset_for_tests()
	if warm:
		# the warm-up as the game runs it: how long, and the worst frame while it runs
		var t0 := Time.get_ticks_msec()
		Game.warmup.start()
		if OS.get_cmdline_user_args().has("main_thread"):
			Game.warmup._threaded = false   # (the web build's path, on the main thread)
		var worst := 0.0
		var frames := 0
		var last := Time.get_ticks_usec()
		while not Game.warmup.finished():
			await tree.process_frame
			var now := Time.get_ticks_usec()
			worst = maxf(worst, (now - last) / 1000.0)
			last = now
			frames += 1
		print("warm-up: %d ms, %d frames, worst frame %.1f ms" % [Time.get_ticks_msec() - t0, frames, worst])
		if not OS.get_cmdline_user_args().has("nosetup"): await _setup_check(tree)
		load("res://src/ui/screens/new_career.gd").stagger_in_tests = not OS.get_cmdline_user_args().has("nostagger")
	var c := Career.new_game("WAGN", "Sam", "Rivera", 31)
	Game.career = c
	for _i in 4:
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	c.queue.clear()
	for q in c.upgrades_due(): Development.ai_spend(q)
	var rows: Array = []
	for pass_i in 2:
		for s in SCREENS:
			if not ResourceLoader.exists(Game.SCREEN_PATHS.get(s, "res://src/ui/screens/%s.gd" % s)):
				continue
			rows.append(await _time(tree, s, {}, pass_i))
		var p := c.team().starters()[1]
		rows.append(await _time(tree, "player", {"id": p.id, "list": c.team().roster.map(func(q): return q.id)}, pass_i))
		rows.append(await _time(tree, "match", {"us": League.make_team(0), "them": League.make_team(1), "seed": 1, "minutes": 1.0}, pass_i))
		Engine.time_scale = 1.0
	rows.sort_custom(func(a, b): return a.total > b.total)
	print("\nscreen            pass   load   new+setup  ready   frame   TOTAL (ms)")
	for r in rows:
		print("%-16s  %s  %6.1f  %8.1f  %6.1f  %6.1f  %7.1f" % [r.name, "warm" if r.pass else "cold",
			r.load, r.setup, r.ready, r.frame, r.total])

## The dynasty setup on its worker thread, as Game.prepare_setup makes it (no seed file here):
## how long, the worst frame meanwhile, and dynasty_setup() taking it.
static func _setup_check(tree: SceneTree) -> void:
	Game.setup = null
	var t0 := Time.get_ticks_msec()
	Game._setup_task = WorkerThreadPool.add_task(func(): Game._setup_made = Career.new_setup(4242))
	var worst := 0.0
	var last := Time.get_ticks_usec()
	while not WorkerThreadPool.is_task_completed(Game._setup_task):
		await tree.process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	var ok := Game.dynasty_setup() != null and Game.dynasty_setup().teams.size() == Colleges.SCHOOLS.size()
	print("threaded setup: %d ms, worst frame %.1f ms, taken by dynasty_setup: %s" % [Time.get_ticks_msec() - t0, worst, ok])

static func _time(tree: SceneTree, name: String, params: Dictionary, pass_i: int) -> Dictionary:
	await tree.process_frame
	await tree.process_frame
	var path: String = Game.SCREEN_PATHS.get(name, "res://src/ui/screens/%s.gd" % name)
	var t0 := Time.get_ticks_usec()
	var scr: Script = load(path)
	var t1 := Time.get_ticks_usec()
	var node: Control = scr.new()
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.theme = UI.theme
	if node.has_method("setup"):
		node.setup(params)
	var t2 := Time.get_ticks_usec()
	if Game.current_screen != null:
		Game.current_screen.queue_free()
	Game.current_screen = node
	Game.current_name = name
	Game.screen_root.add_child(node)
	var t3 := Time.get_ticks_usec()
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var t4 := Time.get_ticks_usec()
	return {"name": name, "pass": pass_i, "load": (t1 - t0) / 1000.0, "setup": (t2 - t1) / 1000.0,
		"ready": (t3 - t2) / 1000.0, "frame": (t4 - t3) / 1000.0, "total": (t4 - t0) / 1000.0}

## starters() remembered must always be starters() worked out afresh, whatever changes.
static func fuzz_starters(runner: Node) -> void:
	var c := Career.new_setup(777)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var teams: Array = c.teams.values()
	teams.append(League.make_team(2))
	var bad := 0
	var n := 0
	for it in 6000:
		var t: PoloTeam = teams[rng.randi() % teams.size()]
		var p: PoloPlayer = t.roster[rng.randi() % t.roster.size()]
		match rng.randi() % 10:
			0: p.rolled = not p.rolled
			1: p.susp = rng.randi() % 2
			2: p.attrs[["sho", "pas", "str", "dfn", "blk", "lun"][rng.randi() % 6]] = rng.randf_range(1.0, 10.0)
			3: p.lefty = not p.lefty
			4: p.pos = rng.randi() % 6
			5: p.keeping = rng.randi_range(20, 99)
			6:
				if t.lineup.is_empty():
					t.lineup = t.roster.map(func(q): return q.id)
					t.lineup.shuffle()
				else:
					t.lineup = []
			7:
				if not t.lineup.is_empty():
					var i := rng.randi() % t.lineup.size()
					var j := rng.randi() % t.lineup.size()
					var tmp = t.lineup[i]
					t.lineup[i] = t.lineup[j]
					t.lineup[j] = tmp
			8:
				if t.roster.size() > 8:
					t.roster.remove_at(rng.randi() % t.roster.size())
			9:
				var q := PoloPlayer.from_dict(p.to_dict())
				q.id = 100000 + it
				t.roster.append(q)
		for k in 2:   # (twice: the second is the remembered one)
			var got := t.starters()
			var want := t._pick_starters()
			n += 1
			if got != want:
				bad += 1
		if rng.randi() % 3 == 0:
			t.starters().clear()   # (a caller changing the list it got never touches the remembered one)
	print("fuzz starters: %d checks, %d mismatches" % [n, bad])
	runner.check(bad == 0, "starters() remembered always matches a fresh pick")

static func bench(runner: Node) -> void:
	var t := League.make_team(0)
	var c := Career.new_game("WAGN", "Sam", "Rivera", 31)
	var ct: PoloTeam = c.team()
	for tm in [t, ct]:
		var p: PoloPlayer = tm.roster[3]
		var N := 200
		var t0 := Time.get_ticks_usec()
		for i in N: tm.starters()
		var t1 := Time.get_ticks_usec()
		for i in N * 50: p.overall()
		var t2 := Time.get_ticks_usec()
		for i in N * 50: p.is_available()
		var t3 := Time.get_ticks_usec()
		for i in N: tm.power()
		var t4 := Time.get_ticks_usec()
		for i in N: tm.overall_display()
		var t5 := Time.get_ticks_usec()
		for i in N: tm.offense_display()
		var t6 := Time.get_ticks_usec()
		print("roster %d lineup %d | starters %.3f ms | overall %.4f ms | is_available %.4f ms | power %.3f | ovr_disp %.3f | off_disp %.3f" % [tm.roster.size(), tm.lineup.size(),
			(t1 - t0) / 1000.0 / N, (t2 - t1) / 1000.0 / N / 50, (t3 - t2) / 1000.0 / N / 50, (t4 - t3) / 1000.0 / N, (t5 - t4) / 1000.0 / N, (t6 - t5) / 1000.0 / N])
