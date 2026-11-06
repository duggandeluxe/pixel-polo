extends RefCounted
## Each list screen in both modes, to compare: <id>_off.png, <id>_on.png.
##   godot --path game -- --test fine_logos_png <dir>   (needs a window)

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	runner.get_window().size = Vector2i(1440, 810)
	var c := Career.new_game("GWU", "S", "H", 640)
	c.queue.clear()
	c.league_news = [{"id": "t", "team": c.teams.keys()[1], "head": "TEST STORY", "label": "WEEK 1", "text": "A test story."}, {"id": "u", "team": c.school, "head": "OUR STORY", "label": "WEEK 1", "text": "A test story."}]
	Game.career = c
	for id: String in ["hub", "news", "roster", "scout", "quick_match", "awards"]:
		Game.goto(id)
		for i in 6:
			await runner.get_tree().process_frame
		for mode: String in ["off", "on"]:
			Game.set_detail(mode == "on")
			_redraw(Game.current_screen)
			for i in 5:
				await runner.get_tree().process_frame
			var img: Image = runner.get_viewport().get_texture().get_image()
			img.save_png("%s/%s_%s.png" % [dir, id, mode])
	Game.set_detail(false)
	Game.career = null

static func _redraw(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()
	for ch in n.get_children():
		_redraw(ch)
