extends RefCounted
## The small team logos in detail mode's pixels: every school has its fine files, inside the same
## boxes; the list screens opt in; a match doesn't.
##   godot --headless --path game -- --test fine_logos
## Screenshots (needs a window): --test fine_logos_png <dir>

const SCREENS := ["hub", "news", "roster", "scout", "quick_match"]

func run(r) -> void:
	print("fine team logos")
	var all := true
	var n := 0
	for s: Dictionary in Colleges.SCHOOLS:
		for tag: String in TeamLogo.FINE_TAGS:
			var path := TeamLogo.ART_PATH % [String(s.short), TeamLogo.FINE_TAGS[tag]]
			if not ResourceLoader.exists(path):
				continue
			n += 1
			var tex: Texture2D = load(path)
			var b: Vector2i = TeamLogo.ART_BOXES[tag]
			all = all and tex.get_width() * TeamLogo.FINE <= b.x + 0.01 and tex.get_height() * TeamLogo.FINE <= b.y + 0.01
	r.check(n == 58, "29 schools, two fine files each (%d)" % n)
	r.check(all, "each fits the box its coarse file does")
	var c := Career.new_game("GWU", "S", "H", 640)
	c.queue.clear()
	Game.career = c
	var t := c.team()
	r.check(TeamLogo.art(t, Vector2i(20, 12), true).resource_path.ends_with("_fs.png"), "a list box: the fine file")
	r.check(TeamLogo.art(t, Vector2i(28, 20), true).resource_path.ends_with("_fm.png"), "a row box: the fine file")
	r.check(TeamLogo.art(t, Vector2i(60, 60), true).resource_path.ends_with("_60.png"), "the big logos are left alone")
	r.check(TeamLogo.art(t, Vector2i(20, 12)).resource_path.ends_with("_s.png"), "outside detail mode: the plain file")
	var club := {"id": "ZZZ", "name": "Test Club", "c1": "ffffff", "c2": "000000"}
	var mini := TeamLogo.texture(club, true, true)
	var full := TeamLogo.texture(club, false, true)
	r.check(mini.get_width() == 15 and mini.get_height() == 18 and full.get_width() == 30, "a school with no art: the letter in fine pixels too")
	var win: Window = r.get_window()
	for id: String in SCREENS:
		Game.goto(id)
		await r.get_tree().process_frame
		r.check(win.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and not win.oversampling, "%s: detail mode" % id)
	Game.goto("more")
	await r.get_tree().process_frame
	r.check(win.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT and win.oversampling, "and off again")
	Game.career = null
