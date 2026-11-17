extends RefCounted
## The School Record Book's team marks: WINS IN A SEASON names its coach ("COACH RINALDI"); TEAM
## GOALS IN A GAME and BIGGEST WIN name their game ("2023 HAMMERHEADS VS. CAMBRIDGE REDHAWKS"),
## the opponent's whole name, never only its mascot. Chosen once, kept in the save.
##   godot --headless --path game -- --test record_holders
##   godot --path game --resolution 480x270 -- --test record_holders_png <dir>

var r

func _frames(n: int) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _texts(root: Node) -> String:
	var out := PackedStringArray()
	for n in root.find_children("*", "", true, false):
		if n is Label or n is Button:
			out.append(n.text)
	return "\n".join(out)

func run(runner) -> void:
	r = runner
	print("record holders")
	Store.reset_for_tests()
	var c := Career.new_game("LIUB", "A", "Rinaldi", 61)
	var canon := Records.canon_school(c.school)
	var book := Records.school_book(c, c.school)
	# values and years: the canon's, untouched
	var same := true
	for k in Records.KEYS:
		same = same and int(book[k].v) == int(canon[k].v) and str(book[k].year) == str(canon[k].year) and String(book[k].name) == String(canon[k].name)
	r.check(same, "7: every record's value and year (and the player books' holders) unchanged")
	# wins in a season: a former coach, not a player
	var coach := String(book.season_wins.get("coach", ""))
	var sw := Records.holder_text(c, "season_wins", book.season_wins)
	r.check(coach != "" and sw == "COACH " + coach.to_upper() and not sw.contains("."), "1: WINS IN A SEASON is COACH [LAST NAME] (%s)" % sw)
	# team goals, biggest win: the year, your mascot, the opponent's whole name
	var mascot := String(c.team().mascot).to_upper()
	for k in ["game_team_goals", "game_margin"]:
		var m: Dictionary = book[k]
		var opp := String(m.get("opp", ""))
		var t := Records.holder_text(c, k, m)
		var want := "%s %s VS. %s" % [str(m.year), mascot, String(c.teams[opp].name).to_upper()] if c.teams.has(opp) else ""
		r.check(c.teams.has(opp) and opp != c.school and t == want, "2-3: %s is YEAR MASCOT VS. FULL NAME (%s)" % [k, t])
		r.check(String(c.teams[opp].name).length() > String(c.teams[opp].mascot).length() and t.ends_with(String(c.teams[opp].name).to_upper()), "4: %s's opponent is its whole name, not its mascot" % k)
		r.check(not t.contains(String(canon[k].name).to_upper()), "5: no player's name holds %s" % k)
	# chosen once: the same on every look, and through a save
	var again := Records.school_book(c, c.school)
	r.check(String(again.season_wins.coach) == coach and String(again.game_margin.opp) == String(book.game_margin.opp), "the holders don't change when the book is read again")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var bb := Records.school_book(back, back.school)
	r.check(String(bb.season_wins.coach) == coach and String(bb.game_team_goals.opp) == String(book.game_team_goals.opp)
		and String(bb.game_margin.opp) == String(book.game_margin.opp), "10: the holders survive a save and reload")
	# an older save (no coach, no opponent in its book): filled on load, values kept
	var old: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	for k in ["season_wins", "game_team_goals", "game_margin"]:
		(old.records.school[c.school][k] as Dictionary).erase("coach")
		(old.records.school[c.school][k] as Dictionary).erase("opp")
	var oc := Career.from_dict(old)
	var ob := Records.school_book(oc, oc.school)
	r.check(int(ob.game_margin.v) == int(canon.game_margin.v) and String(ob.season_wins.coach) == coach
		and String(ob.game_margin.opp) == String(book.game_margin.opp), "10: an older save gets the same holders, its values kept")
	# new records: your coach, the real opponent
	var opp_id := String(c.teams.keys().filter(func(id): return id != c.school)[0])
	var big := int(book.game_team_goals.v) + 1
	Records.game_breaks(c, c.school, [], null, 0, big, 0, opp_id)
	var nb := Records.school_book(c, c.school)
	r.check(int(nb.game_team_goals.v) == big and String(nb.game_team_goals.opp) == opp_id and int(nb.game_margin.v) == big and String(nb.game_margin.opp) == opp_id
		and Records.holder_text(c, "game_margin", nb.game_margin) == "%s %s VS. %s" % [c.season_label(), mascot, String(c.teams[opp_id].name).to_upper()],
		"8: a new team-goals / biggest-win record keeps its season and its opponent's whole name")
	var small := Records.game_breaks(c, c.school, [], null, 0, big + 1, big, opp_id)
	r.check(int(Records.school_book(c, c.school).game_margin.v) == big, "the biggest win is still the margin, not the goals (%d)" % small.size())
	Records.breaks(c, "season_wins", int(nb.season_wins.v) + 1, c.team().name, c.school, {"coach": String(c.coach.last)})
	r.check(Records.holder_text(c, "season_wins", Records.school_book(c, c.school).season_wins) == "COACH RINALDI", "8: your record season names you")
	var rt := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(String(Records.school_book(rt, rt.school).game_team_goals.opp) == opp_id and String(Records.school_book(rt, rt.school).season_wins.coach) == "Rinaldi",
		"8, 10: the new holders survive a save and reload")
	# the screen: holders shown whole, no legend, nothing over YEAR
	Game.career = c
	Game.goto("records")
	await _frames(2)
	Game.current_screen.tab = "TEAM"
	Game.current_screen._render()
	await _frames(3)
	var sb: Node = Game.current_screen.find_child("SchoolBook", true, false)
	var txt := _texts(sb)
	r.check(not txt.contains("GOLD HOLDER") and not _texts(Game.current_screen).contains("GOLD HOLDER"), "6: the GOLD HOLDER line is gone")
	var whole := true
	for k in ["season_wins", "game_team_goals", "game_margin"]:
		var row: Control = sb.find_child("Record_" + k, true, false)
		var hl: Label = row.find_child("Holder", true, false)
		var yr: Control = row.get_child(row.get_child_count() - 1)
		whole = whole and hl != null and hl.text == Records.holder_text(c, k, Records.school_book(c, c.school)[k])
		whole = whole and hl.get_global_rect().end.x <= yr.get_global_rect().position.x
	r.check(whole, "9: every team holder shown whole (wrapped, never cut) and clear of YEAR")
	Game.career = null

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Store.reset_for_tests()
	var c := Career.new_game("BUCK", "A", "Rinaldi", 64)
	Game.career = c
	Game.goto("records")
	await runner.get_tree().process_frame
	Game.current_screen.tab = "TEAM"
	Game.current_screen._render()
	await runner.get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("record_holders_team.png"))
	var sc: ScrollContainer = Game.current_screen.find_children("*", "ScrollContainer", true, false)[0]
	sc.scroll_vertical = 10000
	await runner.get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("record_holders_team_bottom.png"))
	runner.get_tree().quit()
