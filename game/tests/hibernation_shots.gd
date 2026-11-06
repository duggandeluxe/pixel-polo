extends RefCounted
## Screenshots of the screens the lower divisions' hibernation changes (Colleges.ENABLE_LOWER_DIVISIONS
## off): the school picker, the dynasty setup, the coin shop, career select. Needs a window:
##   godot --path game -- --test hibernation_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Store.reset_for_tests()
	Store._grant("pro_unlock", "purchase", "shots-1")   # (owning both packs: still nothing shows)
	Game.goto("new_career")
	await _shot(runner, tree, out, "h1_pick_school")
	var nc = Game.current_screen
	nc._next()   # (the school it opened on: an open one)
	await _shot(runner, tree, out, "h2_setup")
	Game.goto("store")
	await _shot(runner, tree, out, "h3_shop")
	Game.goto("careers")
	await _shot(runner, tree, out, "h4_careers")
	Store.reset_for_tests()

static func _shot(runner: Node, tree: SceneTree, out: String, name: String) -> void:
	await tree.create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)
