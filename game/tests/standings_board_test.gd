extends RefCounted
## THE CONFERENCE RANKINGS VISUAL OVERHAUL: the conference screen's full-width standings board
## (five equal conference buttons, the full name, a row a team: rank with gold / silver / bronze,
## big name, CONF, ALL, GF-GA, rating and its bar; your row in gold; the leader's star; CHAMPION /
## QUALIFIED only once the season has settled them; no logos) and the CHAMPIONSHIP QUALIFICATION
## panel; the Top 20 in the same style. The numbered checks follow the spec's REQUIRED TESTING list.
##   godot --headless --path game -- --test standings_board
##   godot --path game -- --test standings_board_png <dir>

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("standings board")
	Store.reset_for_tests()
	var c := Career.new_game("ICU", "A", "B", 61)
	c.queue.clear()
	c.hot_tip = true
	Game.career = c
	var scr = await _open("conference")
	_board(scr, c, false)
	# a few weeks in
	for _i in 4:
		_week(c)
	scr = await _open("conference")
	_board(scr, c, true)
	await _switch(scr, c)
	# past the conference tournaments: champions and the NCSA field picked
	var guard := 0
	while (c.season.get("nat_seeds", []) as Array).is_empty() and guard < 30 and not c.in_offseason():
		guard += 1
		_week(c)
	scr = await _open("conference")
	_badges(scr, c)
	scr = await _open("top20")
	_top20(scr, c)
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _open(name: String) -> Node:
	Game.goto(name, {}, false)
	for _i in 4:
		await r.get_tree().process_frame
	for layer in Game.overlay.get_children():
		if layer is Control and layer.mouse_filter == Control.MOUSE_FILTER_STOP:
			layer.queue_free()
	return Game.current_screen

static func _week(c: Career) -> void:
	while c.has_game():
		c.sim_my_game()
	c.queue.clear()
	for p in c.team().roster:
		while Development.pending(p) > 0:
			var spent := false
			for k in p.key_ratings():
				if Development.spend(p, k):
					spent = true
					break
			if not spent:
				break
	c.end_week()
	c.queue.clear()

func _board(scr, c: Career, played: bool) -> void:
	var tag := "week %d" % c.week
	var board: Control = scr.find_child("Board", true, false)
	var page: float = scr.get_viewport_rect().size.x
	var share: float = board.size.x / page
	r.check(share >= 0.85 and share <= 0.95 and absf(board.get_global_rect().get_center().x - page * 0.5) < 3.0, "T1 %s: the board is %d%% of the page, centred" % [tag, roundi(share * 100)])
	var btns: Array = scr.find_child("ConfButtons", true, false).get_children()
	r.check(btns.map(func(b): return b.text) == ["PEC", "GCC", "WWPC", "NCC", "AWPC"], "T2: the five conference buttons in order")
	var widths: Array = btns.map(func(b): return roundi(b.size.x))
	r.check(widths.max() - widths.min() <= 1, "T2: ...all the same size %s" % str(widths))
	r.check((scr.find_child("ConfTitle", true, false) as Label).text == c.conf_name().to_upper(), "T2: the full name under them")
	var rows: Array = scr.find_child("Rows", true, false).get_children()
	var order := Schedule.conf_table(c.teams, c.table, c.team().conf)
	var ok := rows.size() == order.size()
	var aligned := true
	var x_cols: Array = []
	for i in rows.size():
		var id: String = order[i]
		var t: PoloTeam = c.teams[id]
		var rec: Dictionary = c.table[id]
		var labels: Array = rows[i].find_children("*", "Label", true, false).filter(func(l): return not l.get_parent().name.begins_with("Badge"))
		var tx: Array = labels.map(func(l): return (l as Label).text)
		ok = ok and tx == [str(i + 1), Colleges.display_name(t.name).to_upper(), "%d-%d" % [rec.cw, rec.cl], "%d-%d" % [rec.w, rec.l], "%d-%d" % [rec.gf, rec.ga], str(t.overall_display())]
		var xs: Array = labels.slice(2).map(func(l): return roundi(l.get_global_rect().position.x))
		if x_cols.is_empty():
			x_cols = xs
		aligned = aligned and xs == x_cols
		var rt: Control = rows[i].find_child("Rating", true, false)
		ok = ok and int(rt.get_meta("ovr")) == t.overall_display()
		ok = ok and rows[i].find_children("*", "TextureRect", true, false).is_empty()
		var nm: Label = rows[i].find_child("Name", true, false)
		ok = ok and nm.get_theme_font_size("font_size") == 16
	r.check(ok, "T1/T4/T5 %s: every row: rank, full name (big), CONF, ALL, GF-GA and the real rating; no logos" % tag)
	r.check(aligned, "T1 %s: the numbers line up down the columns" % tag)
	var mine: Control = rows[order.find(c.school)]
	var sb: StyleBoxFlat = mine.get_theme_stylebox("panel")
	r.check(sb.border_color == UI.GOLD and (mine.find_child("Name", true, false) as Label).get_theme_color("font_color") == UI.GOLD, "T3 %s: your team's row in gold" % tag)
	r.check(rows.filter(func(rw): return rw.get_theme_stylebox("panel").border_color == UI.GOLD).size() == 1, "T3: ...and only yours")
	var medals := true
	for i in mini(3, rows.size()):
		medals = medals and (rows[i].find_child("Rank", true, false) as Label).get_theme_color("font_color") == scr.MEDALS[i]
	r.check(medals and (rows[3].find_child("Rank", true, false) as Label).get_theme_color("font_color") == UI.DIM, "T10: 1st gold, 2nd silver, 3rd bronze; the rest plain")
	var stars: Array = rows.filter(func(rw): return rw.find_child("Leader", true, false) != null)
	r.check((stars.size() == 1 and stars[0] == rows[0]) if played else stars.is_empty(), "T12 %s: the leader's star %s" % [tag, "on the first-place team" if played else "waits for conference games"])
	if not played:
		r.check(rows.all(func(rw): return rw.find_children("Badge_*", "", true, false).is_empty()), "T15: nobody CHAMPION or QUALIFIED before it's settled")
	var q: Control = scr.find_child("Qualification", true, false)
	var qt: Array = q.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	r.check(qt[0] == "CHAMPIONSHIP QUALIFICATION" and " ".join(qt).contains("%d-team NCSA Championship" % Schedule.NCSA_FIELD) and " ".join(qt).contains("seeds 1-4 skip"), "T6: the rules in their own panel")
	r.check(not board.find_children("*", "Label", true, false).any(func(l): return l.get_global_rect().end.x > board.get_global_rect().end.x + 0.5), "T9: nothing past the board's edge")

## T2: every conference's button shows its own teams; the bars are the ratings.
func _switch(scr, c: Career) -> void:
	for cid in ["MPSF", "BIGWEST", "WCC", "NWPC", "MAWPC"]:
		(scr.find_child("Conf_" + cid, true, false) as Button).pressed.emit()
		for _i in 2:
			await r.get_tree().process_frame
		var rows: Array = scr.find_child("Rows", true, false).get_children()
		var order := Schedule.conf_table(c.teams, c.table, cid)
		r.check(rows.map(func(rw): return String(rw.name).trim_prefix("Row_")) == order and (scr.find_child("ConfTitle", true, false) as Label).text == c.conf_name(cid).to_upper(), "T2: %s's teams, in its standings order" % c.conf_abbr(cid))
		r.check(scr.conf == cid, "T2: %s picked" % c.conf_abbr(cid))
	scr.conf = c.team().conf
	scr._render()

## T15: CHAMPION and QUALIFIED only on what the season says.
func _badges(scr, c: Career) -> void:
	var champs: Array = c.season.get("conf_champs", [])
	var field: Array = c.season.get("nat_seeds", [])
	var right := true
	for cid in ["MPSF", "BIGWEST", "WCC", "NWPC", "MAWPC"]:
		scr.conf = cid
		scr._render()
		for rw in scr.find_child("Rows", true, false).get_children():
			var id := String(rw.name).trim_prefix("Row_")
			var want := "Badge_CHAMPION" if id in champs else ("Badge_QUALIFIED" if id in field else "")
			var got: Array = rw.find_children("Badge_*", "", true, false).map(func(b): return String(b.name))
			right = right and got == ([want] if want != "" else [])
	r.check(not champs.is_empty() and right, "T15: CHAMPION on the %d conference champions, QUALIFIED on the at-large teams, nothing else" % champs.size())

func _top20(scr, c: Career) -> void:
	var t: Control = scr.find_child("Top20Table", true, false)
	var rows: Array = t.get_meta("rows")
	var poll: Dictionary = (c.season.polls as Array)[-1]
	r.check(rows.slice(0, Poll.TOP).map(func(d): return d.id) == Poll.rows(c, poll).slice(0, Poll.TOP).map(func(d): return d.id), "T7: the Top 20 in the poll's order")
	var drawn: Array = []
	UI.drawn_log = drawn
	t.queue_redraw()
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	UI.drawn_log = null
	r.check(drawn.has(Colleges.display_name((c.teams[rows[0].id] as PoloTeam).name).to_upper()), "T7: the full names, written out")
	r.check(t.find_children("*", "", true, false).is_empty() and scr.find_child("Logo", true, false) == null, "T5/T7: no logos in the Top 20")

## Shots: the conference board early and late, and the Top 20.
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	var c := Career.new_game("ICU", "A", "B", 61)
	c.queue.clear()
	c.hot_tip = true
	Game.career = c
	for st in [[4, "b1_week5"], [20, "b2_playoffs"]]:
		var guard := 0
		while guard < int(st[0]) and not c.in_offseason() and ((c.season.get("nat_seeds", []) as Array).is_empty() or String(st[1]) == "b1_week5"):
			guard += 1
			_week(c)
		for sz in [[Vector2i(1440, 810), ""], [Vector2i(1752, 810), "_wide"], [Vector2i(1080, 810), "_4x3"]]:
			DisplayServer.window_set_size(sz[0])
			await tree.create_timer(0.3).timeout
			for scr in ["conference", "top20"]:
				Game.goto(scr, {}, false)
				await tree.create_timer(0.4).timeout
				for layer in Game.overlay.get_children():
					if layer is Control and layer.mouse_filter == Control.MOUSE_FILTER_STOP:
						layer.queue_free()
				await tree.create_timer(0.1).timeout
				runner.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s%s.png" % [st[1], scr, sz[1]]))
				print("  shot ", st[1], " ", scr, sz[1])
	DisplayServer.window_set_size(Vector2i(1440, 810))
	Game.career = null
	Game.goto("title")
