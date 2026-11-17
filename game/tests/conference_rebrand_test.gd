extends RefCounted
## THE CONFERENCE REBRANDING & RANKINGS CLEANUP: the five conferences show their new names (ids,
## memberships, schedules untouched), and the conference standings list has no team logos and no
## room kept for them. The numbered checks follow the spec's REQUIRED TESTING list.
##   godot --headless --path game -- --test conf_rebrand

var r   # the test runner

const NAMES := {"MPSF": ["Pacific Elite Conference", "PEC"], "BIGWEST": ["Golden Coast Conference", "GCC"],
	"WCC": ["Western Water Polo Conference", "WWPC"], "MAWPC": ["Atlantic Water Polo Conference", "AWPC"],
	"NWPC": ["Northeast Coast Conference", "NCC"]}
const MEMBERS := {"MPSF": 4, "BIGWEST": 6, "WCC": 8, "MAWPC": 7, "NWPC": 5}

func run(runner) -> void:
	r = runner
	print("conference rebrand")
	Store.reset_for_tests()
	_names()
	await _cards()
	await _standings()
	await _old_save()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _frames(n := 3) -> void:
	for _i in n:
		await r.get_tree().process_frame

# ------------------------------------------------------------------ T1
func _names() -> void:
	var ok := true
	for id in NAMES:
		ok = ok and Colleges.conference(id).name == NAMES[id][0] and Colleges.conf_abbr(id) == NAMES[id][1]
	r.check(ok, "T1: PEC, GCC, WWPC, AWPC and NCC, by their old ids")
	var sizes := {}
	for id in MEMBERS:
		sizes[id] = Colleges.schools_in(id).size()
	r.check(sizes == MEMBERS, "T1: every school still in its conference %s" % str(sizes))
	var src := ""
	for f in ["res://src/ui/screens/hub.gd", "res://src/ui/screens/conference.gd", "res://src/core/career.gd", "res://src/ui/screens/game_summary.gd", "res://src/ui/screens/new_career.gd"]:
		src += FileAccess.get_file_as_string(f)
	r.check(not src.contains("conf_name().to_upper(), 20") and not src.contains("(MPSF, Big West") and src.contains("(PEC, GCC, WWPC, AWPC, NCC)"), "T1: no old conference name left in what the game says")

# ------------------------------------------------------------------ T2, T5
func _cards() -> void:
	Game.career = null
	Game.progress = Progression.fresh()
	Game.goto("new_career")
	await _frames(4)
	var scr = Game.current_screen
	var wrong: Array = []
	for id in scr.cards:
		var tx: Array = scr.cards[id].find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
		if not Colleges.conf_abbr(Colleges.school(id).conf) in tx or scr.cards[id].find_child("Logo", true, false) == null:
			wrong.append(id)
	r.check(wrong.is_empty(), "T2/T5: every school card shows its new conference and keeps its logo %s" % str(wrong))
	Game.progress = null

# ------------------------------------------------------------------ T3, T4, T7
func _standings() -> void:
	var c := Career.new_game("SJCU", "A", "B", 21)
	c.queue.clear()
	Game.career = c
	_play(c, 3)
	var before := JSON.stringify(c.table)
	var sched := JSON.stringify(c.schedule)
	Game.goto("conference")
	await _frames(4)
	var scr = Game.current_screen
	for cid in NAMES:
		scr.conf = cid
		scr._render()
		await _frames(2)
		var title: Label = scr.find_child("ConfTitle", true, false)
		var btn: Button = scr.find_child("Conf_" + cid, true, false)
		r.check(title != null and title.text == NAMES[cid][0].to_upper() and btn != null and btn.text == NAMES[cid][1], "T1/T3: %s's board is headed %s, its button %s" % [cid, title.text if title else "-", btn.text if btn else "-"])
		var rows: Array = scr.find_child("Rows", true, false).get_children()
		var order := Schedule.conf_table(c.teams, c.table, cid)
		r.check(rows.size() == order.size() and rows.size() == MEMBERS[cid], "T3: %s: one row a school (%d)" % [NAMES[cid][1], rows.size()])
		r.check(rows.all(func(rw): return rw.find_child("Logo", true, false) == null and rw.find_children("*", "TextureRect", true, false).is_empty()), "T3: %s: no logos, no logo boxes" % NAMES[cid][1])
		var right := true
		for i in rows.size():
			right = right and String(rows[i].name) == "Row_" + order[i] and (rows[i].find_child("Name", true, false) as Label).text == Colleges.display_name((c.teams[order[i]] as PoloTeam).name).to_upper()
		r.check(right, "T4: %s: the table's order and names" % NAMES[cid][1])
	r.check(JSON.stringify(c.table) == before and JSON.stringify(c.schedule) == sched, "T4: looking changes no record or schedule")
	# the playoffs keep their logos (only the standings list lost them)
	scr.tab = "PLAYOFFS"
	scr._render()
	await _frames(2)
	r.check(scr.find_children("*", "Label", true, false).size() > 0, "T5: the playoffs tab still draws")
	Game.goto("hub")
	await _frames(3)
	var hub_txt: Array = Game.current_screen.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	r.check("WWPC" in hub_txt, "T1: the hub's table is headed WWPC")
	Game.career = null

## `weeks` weeks of the season played (your games simulated, as SIM THIS GAME does).
func _play(c: Career, weeks: int) -> void:
	var stop := c.week + weeks
	var guard := 0
	while c.week < stop and guard < 40:
		guard += 1
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

func _unused_rows(scr) -> Array:
	var out: Array = []
	for h in scr.find_children("*", "HBoxContainer", true, false):
		if h.get_child_count() == 6 and h.get_children().all(func(k): return k is Label) and (h.get_child(0) as Label).text.is_valid_int():
			out.append(h)
	if out.is_empty():
		# (a row that still had a logo in it: count it so the logo check fails loudly)
		for h in scr.find_children("*", "HBoxContainer", true, false):
			if h.get_child_count() == 7 and (h.get_child(0) as Label) != null and (h.get_child(0) as Label).text.is_valid_int():
				out.append(h)
	return out

# ------------------------------------------------------------------ T6
func _old_save() -> void:
	var c := Career.new_game("FORDU", "A", "B", 33)
	_play(c, 2)
	c.coach.titles = ["2025-26 MPSF", "2025-26 Big West", "2025-26 NCSA"]
	c.add_news("CONFERENCE CHAMPIONS! Bronx Lambs win the MAWPC")
	c.add_news("New Jersey Bengals win the Northeast Collegiate Conference")   # (a save from between the two renames)
	c.queue.append({"type": "note", "title": "WCC preview", "text": "Finish top 3 in the NWPC", "lines": ["Big West next"]})
	var d: Dictionary = c.to_dict()
	var table := JSON.stringify(c.table)
	var sched := JSON.stringify(c.schedule)
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	r.check(back.coach.titles == ["2025-26 Pacific Elite Conference", "2025-26 Golden Coast Conference", "2025-26 NCSA"], "T6: an old dynasty's titles in the new names %s" % str(back.coach.titles))
	r.check(back.news.any(func(n): return String(n.t).ends_with("win the Atlantic Water Polo Conference")), "T6: ...its news too")
	r.check(back.news.any(func(n): return String(n.t) == "New Jersey Bengals win the Northeast Coast Conference") and not back.news.any(func(n): return "Collegiate" in String(n.t)), "NCC: Northeast Collegiate Conference in a save becomes Northeast Coast Conference")
	var q: Dictionary = back.queue[-1]
	r.check(q.title == "Western Water Polo Conference preview" and q.text == "Finish top 3 in the Northeast Coast Conference" and q.lines == ["Golden Coast Conference next"], "T6: ...and its inbox")
	r.check(back.team().conf == "MAWPC" and JSON.stringify(back.table) == table and JSON.stringify(back.schedule) == sched, "T6: its conference, records and schedule as they were")
	var again := Career.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())))
	r.check(again.coach.titles == back.coach.titles, "T6: loading twice changes nothing more")
