extends RefCounted
## Screenshots of the shop's areas.
##   godot --path game -- --test shop_png <outdir>   (needs a window)

static func run(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	runner.get_window().size = Vector2i(1440, 810)
	Store.reset_for_tests()
	var c := Career.new_game("GWU", "S", "H", 640)
	c.queue.clear()
	c.add_credits(125, "WIN")
	Game.career = c
	Store.bank.credit(900, "T-SHOT")
	Store.looks.buy_celeb(VisualUpgrades.CONFETTI if Store.looks.celebs.is_empty() else VisualUpgrades.FIREWORKS, c)
	Store.looks.buy_celeb(VisualUpgrades.CONFETTI if Store.looks.celebs.is_empty() else VisualUpgrades.FIREWORKS, c)
	Game.goto("more")
	await _snap(runner, dir, "HUB")
	Game.goto("store")
	await _snap(runner, dir, "STORE")
	Game.goto("visual_shop")
	for i in 3:
		await runner.get_tree().process_frame
	await _snap(runner, dir, "GALLERY")
	# GOAL CELEBRATIONS: the four cards (CONFETTI and FIREWORKS owned above, FIREWORKS equipped)
	Game.goto("upgrade_detail", {"cat": "goal"})
	for i in 3:
		await runner.get_tree().process_frame
	await _snap(runner, dir, "CELEBRATIONS")
	Game.current_screen.select(3)
	for i in 3:
		await runner.get_tree().process_frame
	await _snap(runner, dir, "CELEBRATIONS_WATER")
	Game.goto("store")
	var sc: ScrollContainer = Game.current_screen.body.get_child(Game.current_screen.body.get_child_count() - 1)
	await _snap(runner, dir, "STORE_TOP")
	# a pack hovered (its edge lit), then held down (into its shadow), mid-shimmer
	var leg: Control = Game.current_screen.find_child("Pack_blue_1400", true, false)
	_move(runner, leg.get_global_rect().get_center())
	Game.current_screen.anim_t = 0.25
	await _snap(runner, dir, "STORE_HOVER")
	var gd: Control = Game.current_screen.find_child("Pack_blue_350", true, false)
	_move(runner, gd.get_global_rect().get_center())
	await runner.get_tree().process_frame
	_click(runner, gd.get_global_rect().get_center(), true)
	await _snap(runner, dir, "STORE_PRESSED")
	_move(runner, Vector2(240, 262))   # let go off the card: no purchase
	await runner.get_tree().process_frame
	_click(runner, Vector2(240, 262), false)
	sc = Game.current_screen.body.get_child(Game.current_screen.body.get_child_count() - 1)
	sc.scroll_vertical = 100000
	await _snap(runner, dir, "STORE_END")
	Game.goto("recruiting")
	await _snap(runner, dir, "RECRUITING")
	Game.goto("program")
	await _snap(runner, dir, "PROGRAM")
	for id in ["goal", "crowd", "broadcast", "pregame"]:
		Game.goto("upgrade_detail", {"cat": id})
		for i in 4:
			await runner.get_tree().process_frame
		var d = Game.current_screen
		d.select(VisualUpgrades.top(id))
		d.play_level()
		for i in 150:
			d._process(1.0 / 30.0)
			if i == 45 or i == 149:
				await _snap(runner, dir, "D_%s_%d" % [id, i])
	Store.reset_for_tests()
	Game.career = null

## The mouse to `at` (the 480 x 270 canvas; events come in window pixels).
static func _move(runner, at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _win(runner, at)
	e.global_position = e.position
	Input.parse_input_event(e)

static func _click(runner, at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.position = _win(runner, at)
	e.global_position = e.position
	Input.parse_input_event(e)

static func _win(runner, at: Vector2) -> Vector2:
	return runner.get_viewport().get_final_transform() * at

static func _snap(runner, dir: String, name: String) -> void:
	for i in 3:
		await runner.get_tree().process_frame
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
