extends RefCounted
## The Starting Seven at the game's size, the shop preview's and in Reduce Motion.
##   godot --path game -- --test starting_seven_png <dir>   (needs a window)

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	runner.get_window().size = Vector2i(1440, 810)
	Store.reset_for_tests()
	Store.bank.credit(875, "T")
	for i in 3:
		Store.buy_tier("pregame")
	var c := Career.new_game("GWU", "S", "H", 640)
	c.queue.clear()
	Game.career = c
	Game.match_cfg = {"us": c.team(), "them": c.teams["CULA"], "seed": 77, "minutes": 2.0, "autoplay": true, "intro": true, "replay": false, "home": true, "stage": "REGULAR SEASON"}
	Game.goto("match")
	for i in 4:
		await runner.get_tree().process_frame
	var it: PregameIntro = Game.current_screen.intro
	for shot in [["home", it.seven_at(0) + 1.5], ["away", it.seven_at(1) + 1.5], ["enter", it.seven_at(0) + 0.33], ["wipe", it.seven_at(1) - 0.15], ["sweep", it.seven_at(0) + 0.95], ["matchup", it.length() - 0.6]]:
		it.hold = float(shot[1])
		await _snap(runner, dir, String(shot[0]))
	it.hold = -1.0
	it.skip()
	Game.goto("upgrade_detail", {"cat": "pregame"})
	for i in 4:
		await runner.get_tree().process_frame
	var d = Game.current_screen
	d.select(4)
	d.play_level()
	var n := 0
	while d.cine != null and d.cine.t < d.cine.seven_at(0) + 1.3 and n < 400:
		d._process(1.0 / 30.0)
		n += 1
	d.cine.hold = d.cine.t
	await _snap(runner, dir, "preview")
	Game.goto("cinema_lab")
	for i in 4:
		await runner.get_tree().process_frame
	var lab = Game.current_screen
	lab.seven(1)
	lab.intro.hold = lab.intro.t + 1.4
	await _snap(runner, dir, "lab")
	Store.reset_for_tests()
	Game.career = null

static func _snap(runner, dir: String, name: String) -> void:
	for i in 5:
		await runner.get_tree().process_frame
	runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
