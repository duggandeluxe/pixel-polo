extends RefCounted
## The hub's POLO + badge (PIXEL POLO + owned): normal, hover and pressed, the whole screen and
## the top bar blown up 4x. Quick: no games are simmed. Needs a window:
##   godot --path game --resolution 480x270 -- --test polo_plus_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Store.reset_for_tests()
	Store.pro = true
	var c := Career.new_game("WAGN", "Sam", "Rivera", 31)
	c.queue.clear()
	Game.career = c
	Game.goto("hub")
	await tree.create_timer(0.5).timeout
	for ch in Game.overlay.get_children():   # whatever the hub opened on top
		if ch is Control and ch.mouse_filter == Control.MOUSE_FILTER_STOP:
			ch.queue_free()
	await tree.create_timer(0.2).timeout
	var b: Button = Game.current_screen.find_child("PoloPlus", true, false)
	if b == null:
		push_error("no PoloPlus button on the hub")
		return
	print("  PoloPlus rect ", b.get_global_rect())
	await _shot(runner, out, "pp_normal", b)
	# hover: the mouse moved over it; pressed: held down (toggle mode, so it stays down for the shot)
	var mv := InputEventMouseMotion.new()
	mv.position = b.get_global_rect().get_center()
	mv.global_position = mv.position
	Input.parse_input_event(mv)
	await tree.create_timer(0.1).timeout
	b.queue_redraw()
	await _shot(runner, out, "pp_hover", b)
	b.toggle_mode = true
	b.set_pressed_no_signal(true)
	b.queue_redraw()
	await _shot(runner, out, "pp_down", b)
	b.set_pressed_no_signal(false)
	b.toggle_mode = false
	Store.reset_for_tests()
	Game.career = null

static func _shot(runner: Node, out: String, name: String, b: Button) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := runner.get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	var r := Rect2i(0, 0, img.get_width(), int(b.get_global_rect().end.y) + 6)
	var bar := img.get_region(r)
	bar.resize(bar.get_width() * 4, bar.get_height() * 4, Image.INTERPOLATE_NEAREST)
	bar.save_png(out.path_join(name + "_bar4x.png"))
	print("  shot ", name)
