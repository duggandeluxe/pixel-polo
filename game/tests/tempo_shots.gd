extends RefCounted
## Screenshot tour of Developer Mode's SHOT & TEMPO TEST: the shot race, a passing table and the
## wide-against-on-target comparison, mid-flight. Needs a window:
##   godot --path game -- --test tempo_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Game.goto("tempo_lab")
	await tree.create_timer(0.3).timeout
	var lab = Game.current_screen
	await _shot(runner, out, "t_start")
	lab.team_rating = 95
	lab.test_shot()
	await tree.create_timer(0.35).timeout
	await _shot(runner, out, "t_shot")
	lab.team_rating = 55
	lab.test_passing()
	lab.team_rating = 95
	lab.test_passing()
	await tree.create_timer(0.2).timeout
	await _shot(runner, out, "t_passing")
	lab.test_wide()
	await tree.create_timer(0.3).timeout
	await _shot(runner, out, "t_wide")
	Game.goto("title")

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
