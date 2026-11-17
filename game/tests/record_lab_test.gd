extends RefCounted
## RECORD CELEBRATIONS (RecordShow) and Developer Mode's RECORD ROOM ANIMATIONS lab (record_lab):
## records broken are reported exactly as before and handed to the summary; every lab button
## plays its animation or opens its Trophy Room arrangement; nothing a career or save holds moves.
##   godot --headless --path game -- --test record_lab
##   godot --path game -- --test record_lab_png <dir>

var r

func run(runner) -> void:
	r = runner
	print("record celebrations & the record lab")
	Store.reset_for_tests()
	_breaks()
	await _summary_data()
	await _lab()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n := 2) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _breaks() -> void:
	var c := Career.new_game("SJCU", "A", "B", 61)
	var nb: Dictionary = Records.ncsa_book(c).duplicate(true)
	var sb: Dictionary = Records.school_book(c, c.school).duplicate(true)
	var out := Records.breaks(c, "game_goals", 30, "R. TEST", c.school)
	r.check(out.size() == 2 and out[0].level == "ncsa" and out[1].level == "school", "a mark past both books: an NCSA and a school record, the NCSA's first")
	r.check(int(out[0].prev.v) == int(nb.game_goals.v) and int(out[1].prev.v) == int(sb.game_goals.v), "each carries the mark it beat")
	r.check(String(out[0].line).begins_with("NCSA RECORD! Goals in a game: 30") and String(out[1].line) == "SCHOOL RECORD! Goals in a game: 30, R. TEST", "the news lines as ever (%s)" % str(out.map(func(e): return e.line)))
	r.check(int(Records.ncsa_book(c).game_goals.v) == 30, "the book updated")
	r.check(Records.check(c, "game_goals", 31, "R. TEST", c.school).size() == 2 and Records.check(c, "game_goals", 5, "R. TEST", c.school).is_empty(), "check() still returns the lines, nothing for a mark short of the book")
	var other: String = c.teams.keys().filter(func(id): return id != c.school)[0]
	var theirs := Records.breaks(c, "game_saves", 99, "X. OTHER", other)
	r.check(theirs.size() == 1 and theirs[0].level == "ncsa", "another school's record: its NCSA mark reported, its school book kept quietly (as before)")

func _summary_data() -> void:
	var c := Career.new_game("SJCU", "A", "B", 62)
	c.queue.clear()
	Records.ncsa_book(c)
	for k in c.records.ncsa:
		c.records.ncsa[k].v = 0   # (every mark falls)
	c.records.school.erase(c.school)
	Records.school_book(c, c.school)
	for k in c.records.school[c.school]:
		c.records.school[c.school][k].v = 0
	var sm := c.sim_my_game()
	var rec: Array = sm.get("records", [])
	r.check(not rec.is_empty() and rec.all(func(e): return String(e.line) in (sm.lines as Array)), "a game's records go to the summary (%d), each also in its lines" % rec.size())

func _lab() -> void:
	# a loaded career, as a developer would have: nothing in it may move
	var c := Career.new_game("SJCU", "A", "B", 63)
	c.queue.clear()
	Game.career = c
	var before := JSON.stringify(c.to_dict())
	Game.goto("record_lab")
	await _frames(3)
	var lab = Game.current_screen
	var plays: Array = lab.find_children("Play_*", "Button", true, false)
	r.check(plays.size() == Records.KEYS.size() * 2, "a button for every record, NCSA and school (%d)" % plays.size())
	var ok := true
	for b: Button in plays:
		b.pressed.emit()
		await _frames(1)
		var shows: Array = lab.get_children().filter(func(n): return n is RecordShow)
		ok = ok and shows.size() == 1 and (shows[0] as RecordShow).items.size() == 1
		var parts := String(b.name).split("_")
		ok = ok and String((shows[0] as RecordShow).items[0].level) == parts[parts.size() - 1]
	r.check(ok, "each plays its own celebration (one at a time)")
	var show: RecordShow = lab.get_children().filter(func(n): return n is RecordShow)[0]
	show.t = 1.0
	show._next()
	await _frames(1)
	r.check(not is_instance_valid(show) or show.is_queued_for_deletion(), "a tap ends it")
	(lab.find_child("Replay", true, false) as Button).pressed.emit()
	await _frames(1)
	r.check(lab.get_children().any(func(n): return n is RecordShow), "REPLAY plays it again")
	var rooms: Array = lab.find_children("Room_*", "Button", true, false)
	r.check(rooms.size() == 8, "eight Trophy Room arrangements")
	var counts := {}
	for kind in ["empty", "weekly", "one", "national", "full", "max", "keeper", "legacy"]:
		(Game.current_screen.find_child("Room_" + kind, true, false) as Button).pressed.emit()
		await _frames(3)
		var room = Game.current_screen
		var ok_room: bool = Game.current_name == "trophy_room" and room.preview != null and room.preview != c
		var all: Array = room.find_children("*", "", true, false)
		counts[kind] = [all.filter(func(n): return n.has_meta("entry")).size(), all.filter(func(n): return n.has_meta("trophy")).size()]
		ok_room = ok_room and Game.get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		r.check(ok_room, "%s: the room opens on its own throwaway career, in detail mode" % kind)
		room.on_back()
		await _frames(3)
		r.check(Game.current_name == "record_lab" and Game.get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT, "%s: Back to the lab" % kind)
	print("    rooms (plaques, trophies): ", counts)
	r.check(counts.empty == [0, 0] and counts.weekly[1] == 0 and counts.weekly[0] == 5 and counts.one == [0, 1] and counts.national[1] == 7, "the arrangements are what they say (%s)" % str(counts))
	r.check(counts.max[0] == 24 and counts.max[1] == 13 and counts.legacy[0] == 0 and counts.legacy[1] == 3, "...the maxed-out room and an older save's (%s)" % str(counts))
	r.check(Game.career == c and JSON.stringify(c.to_dict()) == before, "the loaded career is exactly as it was")
	# the way out: title > settings > DEV > lab > room > back x4: the title, never round again
	Game.history.clear()
	Game.goto("title")
	await _frames(1)
	Game.goto("settings")
	await _frames(1)
	DevGate.try_unlock("8008")   # (Settings' DEV button and its code)
	Game.goto("dev_settings")
	await _frames(1)
	Game.goto("record_lab")
	await _frames(2)
	Game.current_screen.open_room("max")
	await _frames(2)
	var path: Array = []
	for i in 4:   # (a fifth would be the title's Back: quit)
		Game.current_screen.on_back()
		await _frames(2)
		path.append(Game.current_name)
	r.check(path == ["record_lab", "dev_settings", "settings", "title"], "Back from a preview room leads out: %s" % str(path))
	Game.goto("title")
	await _frames(1)

# ------------------------------------------------------------------ shots
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	Game.career = null
	var snap := func(name: String, wait := 0.4) -> void:
		await tree.create_timer(wait).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
		print("  shot ", name)
	# every trophy, 6x, side by side (and the NCSA's tournament ones)
	var cats := ["poy", "dpoy", "foy", "arm", "wall", "first", "second", "pot", "opot", "dpot"]
	var sheet := Image.create(TrophyArt.W * 6 * 13 + 12 * 4, TrophyArt.H * 6, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0b1d5c"))
	var all: Array = cats.map(func(k): return [k, false if k in ["pot", "opot", "dpot"] else true]) + [["pot", true], ["opot", true], ["dpot", true]]
	for n in all.size():
		var im := TrophyArt.image(String(all[n][0]), bool(all[n][1]))
		im.resize(TrophyArt.W * 6, TrophyArt.H * 6, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(n * (TrophyArt.W * 6 + 4), 0))
	sheet.save_png(out.path_join("trophy_sheet.png"))
	Game.goto("record_lab")
	await snap.call("r0_lab")
	var lab = Game.current_screen
	(lab.find_child("Play_game_goals_ncsa", true, false) as Button).pressed.emit()
	await snap.call("r1_ncsa_pop", 0.3)
	await snap.call("r2_ncsa_full", 2.0)
	(lab.find_child("Play_season_wins_school", true, false) as Button).pressed.emit()
	await snap.call("r3_school_full", 2.3)
	(lab.find_child("Play_career_blocks_ncsa", true, false) as Button).pressed.emit()
	await snap.call("r4_unset", 2.3)
	for kind in ["max", "keeper", "legacy", "weekly"]:
		Game.goto("record_lab")
		await tree.process_frame
		Game.current_screen.open_room(kind)
		await snap.call("t_" + kind, 0.6)
		if kind == "max":
			var cab: Control = Game.current_screen.find_child("Cabinet", true, false)
			var sc: ScrollContainer = cab.find_children("*", "ScrollContainer", true, false)[0]
			sc.scroll_vertical = 10000
			await snap.call("t_max_scrolled", 0.4)
	Game.goto("title")
