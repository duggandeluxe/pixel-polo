extends RefCounted
## Screenshot tour of the title and the career slots, in a scratch save folder (the player's
## own saves are only read: an old single save there is copied in to show the move into a slot).
##   godot --path game -- --test slots_png <dir>

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	var dir := "user://shot_slots/"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))
	var saved_dir := Game.save_dir
	Game.save_dir = dir
	Game.test_mode = false   # so the slots save; screens still change without waiting on taps
	Game._migrated = false
	var mine := FileAccess.get_file_as_string("user://career.json")
	if mine == "":
		mine = FileAccess.get_file_as_string("user://career_slot1.json")
	if mine != "":
		var f := FileAccess.open(dir + Game.LEGACY_SAVE_PATH, FileAccess.WRITE)
		f.store_string(mine)
		f.close()
	# no careers yet: CONTINUE is off
	if mine == "":
		Game.goto("title")
		await tree.create_timer(1.2).timeout
		await _shot(runner, out, "s0_title_no_career")
	# a second career a season and a half in, in slot 3
	var c := Career.new_game("IONA", "Sam", "Rivera", 31)
	while c.year == Career.START_YEAR:
		while c.has_game():
			c.sim_my_game()
		c.end_week()
		if c.week == 0 and c.year > Career.START_YEAR:
			break
	for _i in 6:
		while c.has_game():
			c.sim_my_game()
		c.end_week()
	c.queue.clear()
	Game.slot = 3
	Game.career = c
	Game.save_career()
	Game.career = null
	if mine != "":
		Game.load_career(1)   # the moved save is the one played last
	Game.goto("title")
	await tree.create_timer(1.2).timeout
	await _shot(runner, out, "s1_title")
	Game.goto("careers")
	await tree.create_timer(0.8).timeout
	await _shot(runner, out, "s2_select_career")
	(Game.current_screen.find_child("Delete3", true, false) as Button).pressed.emit()
	await tree.create_timer(0.5).timeout
	await _shot(runner, out, "s3_delete_confirm")
	Game.save_dir = saved_dir
	Game.career = null
	Game.slot = 0
	Game.test_mode = true
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)
