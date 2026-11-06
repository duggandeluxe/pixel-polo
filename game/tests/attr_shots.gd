extends RefCounted
## Screenshot tour of Developer Mode's ATTRIBUTE TEST LAB: a field player, one with big
## attributes VERY HOT, and a goalkeeper. Needs a window:
##   godot --path game -- --test attr_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Game.goto("attr_lab")
	await tree.create_timer(0.3).timeout
	var lab = Game.current_screen
	await _shot(runner, out, "a_field")
	for k in ["pas", "sho"]:
		for _i in 4:
			lab.nudge(k, 1.0, true)
			lab.nudge(k, 1.0)
	lab.nudge("str", -3.0)
	lab.set_form(PlayerForm.VERY_HOT)
	await tree.create_timer(1.0).timeout
	await _shot(runner, out, "a_field_hot")
	lab.set_kind(true)
	lab.nudge("lun", 2.0, true)
	lab.nudge("lun", 2.0)
	lab.set_form(PlayerForm.HOT)
	await tree.create_timer(1.0).timeout
	await _shot(runner, out, "a_keeper")
	Game.goto("title")

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
