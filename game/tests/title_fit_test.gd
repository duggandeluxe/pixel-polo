extends RefCounted
## THE HEADING, NEVER CUT OFF (BaseScreen._fit_title): every screen's title fits its header.
##   godot --headless --path game -- --test title_fit
##   godot --path game -- --test title_fit_png <dir>

const SKIP := ["multiplayer", "hub"]   # (online; the hub draws its own top row)

var r

func run(runner) -> void:
	r = runner
	print("headings never cut off")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	var c := Career.new_game("SJCU", "A", "B", 951)
	c.queue.clear()
	Game.career = c
	var bad: Array = []
	var seen := 0
	for f in DirAccess.get_files_at("res://src/ui/screens"):
		if not f.ends_with(".gd"):
			continue
		var name := f.get_basename()
		if name in SKIP:
			continue
		Game.career = c
		Game.goto(name)
		for _i in 4:
			await r.get_tree().process_frame
		var scr = Game.current_screen
		if scr == null or not (scr is BaseScreen):
			continue
		var tl: Label = scr.title_label
		if tl == null or not tl.is_visible_in_tree() or tl.text == "":
			continue
		seen += 1
		if not fits(tl):
			bad.append("%s: %s (%d px in %d)" % [Game.current_name, tl.text, int(_w(tl)), int(tl.size.x)])
	r.check(seen >= 25 and bad.is_empty(), "every screen's heading fits its header (%d screens) %s" % [seen, str(bad)])
	# the one in the picture: CONFERENCE AWARDS beside the credits and season chips
	Game.goto("awards")
	for _i in 4:
		await r.get_tree().process_frame
	var tl2: Label = Game.current_screen.title_label
	r.check(tl2.text.contains("CONFERENCE") and fits(tl2) and tl2.get_theme_font("font") == UI.font_big, "CONFERENCE AWARDS whole, in the title font (%d px)" % tl2.get_theme_font_size("font_size"))
	# a short title stays big and centred on the page
	Game.goto("settings")
	for _i in 4:
		await r.get_tree().process_frame
	var tl3: Label = Game.current_screen.title_label
	r.check(tl3.get_theme_font_size("font_size") == 20 and absf(tl3.get_global_rect().get_center().x - 240.0) < 2.0, "SETTINGS: as before, 20 px, centred on the page")
	# a very long one falls back without ever clipping
	tl3.text = "A REALLY VERY LONG HEADING THAT CANNOT EVER FIT IN THE HEADER AT ALL"
	for _i in 4:
		await r.get_tree().process_frame
	r.check(tl3.get_theme_font_size("font_size") == 8 or fits(tl3), "an impossible title: the small caps font")
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

static func _w(tl: Label) -> float:
	return tl.get_theme_font("font").get_string_size(tl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tl.get_theme_font_size("font_size")).x

static func fits(tl: Label) -> bool:
	return _w(tl) <= tl.size.x + 0.5

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("SJCU", "A", "B", 951)
	c.queue.clear()
	Game.career = c
	for name in ["awards", "conference", "records", "roster", "settings", "coach_lab"]:
		Game.goto(name)
		await tree.create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("t_%s.png" % name))
	print("  shots")
	Game.career = null
