extends RefCounted
## The Trophy Room's way in and out (headless): TROPHY CASE on a profile opens his room, drawn in
## detail mode; Back returns to the same profile in the same mode (yours, or a scouted opponent's,
## still read-only); every other screen is back at the game's pixels.
##   godot --headless --path game -- --test trophy_nav
static func run(runner) -> void:
	Store.reset_for_tests()
	var c := Career.new_game("LIUB", "A", "B", 81)
	Game.career = c
	var mine: PoloPlayer = c.team().starters()[2]
	for q in c.team().roster:
		if Honours.of(c, q.id).is_empty():   # (one with no past honours: Legacy gives some)
			mine = q
			break
	var other_id := ""
	for id in c.teams:
		if id != c.school:
			other_id = id
			break
	var rival: PoloPlayer = (c.teams[other_id] as PoloTeam).starters()[1]
	c.conf_awards.append({"year": 2026, "season": "2026-27", "week": 0, "label": "WEEK 1", "conf": "NWPC", "cat": "opotw", "pid": rival.id,
		"team": other_id, "name": rival.last, "pos": rival.pos, "cls": 2, "stars": 3.0, "line": {"g": 6, "gp": 1}, "score": 30.0})
	var win: Window = runner.get_window()
	for case in [[mine, {"id": mine.id}, false], [rival, {"id": rival.id, "scout": true}, true]]:
		var p: PoloPlayer = case[0]
		Game.goto("player", case[1])
		await runner.get_tree().process_frame
		var btn: Button = Game.current_screen.find_child("TrophyCase", true, false)
		runner.check(btn != null and btn.size.y <= 12, "TROPHY CASE on %s's page, in the heading's row" % p.last)
		if btn == null:
			continue
		btn.pressed.emit()
		await runner.get_tree().process_frame
		runner.check(Game.current_name == "trophy_room" and int(Game.current_screen.pid) == p.id, "it opens %s's room" % p.last)
		runner.check(win.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and not win.oversampling, "the room is drawn in detail mode")
		var words := _all_text(Game.current_screen)
		runner.check(not "POTENTIAL" in words, "nothing in the room shows potential")
		if case[2]:
			runner.check(Game.current_screen.find_children("Plaque", "", true, false).size() == 1, "the scouted player's plaque is on his board")
		else:
			runner.check(Game.current_screen.find_child("NoWeekly", true, false) != null and Game.current_screen.find_child("NoMajors", true, false) != null,
				"no honours: both empty states")
		Game.current_screen.on_back()
		await runner.get_tree().process_frame
		runner.check(Game.current_name == "player" and int(Game.current_screen.pid) == p.id, "Back: %s's page again" % p.last)
		runner.check(bool(Game.current_screen.scouting) == case[2] and bool(Game.current_screen.viewonly) == case[2],
			"Back keeps the page's mode (scouting %s)" % str(case[2]))
		runner.check(win.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT and win.oversampling, "and the game's own pixels again")
	Game.goto("more")
	await runner.get_tree().process_frame
	runner.check(win.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT, "other screens stay in viewport mode")
	Game.career = null

static func _all_text(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + " "
	for ch in n.get_children():
		out += _all_text(ch)
	return out
