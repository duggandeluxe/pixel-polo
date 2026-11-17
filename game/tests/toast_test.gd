extends RefCounted
## Game.toast (the small notification that drops in at the top of every screen and match):
## frames of each colour over a menu screen and a detail-mode screen, captured from the game's own
## render (480 x 270 on a menu, the window's pixels in detail mode) so the text can be judged.
##   --path game --resolution 1440x810 -- --test toast_png <dir>

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	var snap := func(name: String) -> void:
		await tree.create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name))
		print("  shot " + name)
	Game.career = null
	Game.goto("settings")
	await tree.create_timer(0.4).timeout
	Game.toast("SCOREBOARD: TIER 3 PREMIUM", UI.GOLD)
	await snap.call("t1_gold_viewport.png")
	await tree.create_timer(2.2).timeout
	Game.toast("RECRUIT PINNED", UI.GOOD)
	await snap.call("t2_good_viewport.png")
	await tree.create_timer(2.2).timeout
	Game.toast("NOT ENOUGH CREDITS", UI.BAD)
	await snap.call("t3_bad_viewport.png")
	await tree.create_timer(2.2).timeout
	Game.set_detail(true)
	Game.toast("CROWD: LEVEL 2 PACKED HOUSE", UI.GOLD)
	await snap.call("t4_gold_detail.png")
	await tree.create_timer(2.2).timeout
	Game.toast("+25 {coin} EARNED", UI.GOLD)
	await snap.call("t5_coin_detail.png")
	await tree.create_timer(2.2).timeout
	Game.set_detail(false)
	print("  toast shots")
