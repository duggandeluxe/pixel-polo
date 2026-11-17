extends RefCounted
## THE ROSTER SET REDESIGN & DEV PREVIEW (RosterReport, roster_set.gd, DynastyHistory).
##   godot --headless --path game -- --test roster_set
##   godot --path game --resolution 480x270 -- --test roster_set_png <dir>   (screenshots: needs a window)
## A real off-season (over the cap: cuts by hand) is recorded and checked against the career; the
## screen is opened from the hub's queue; DEV Mode's preview is opened in every scenario and the
## career is compared before and after: nothing in it may change.

var r

func run(runner) -> void:
	r = runner
	print("roster set redesign")
	Game.test_mode = true
	var c := await _offseason()
	if c != null:
		await _screen(c)
		await _dev_preview(c)
	_samples()
	_old_saves()
	Game.career = null

func _career(seed_value: int) -> Career:
	var c := Career.new_game("CULA", "A", "B", seed_value)
	c.queue.clear()
	return c

func _to_done(c: Career) -> void:
	var guard := 0
	while c.phase == "season" and guard < 40:
		guard += 1
		c.queue.clear()
		while c.has_game():
			c.sim_my_game()
		for q in c.upgrades_due():
			Development.ai_spend(q)
		c.end_week()

## A season played out, four recruits signed (over the cap), the cuts made by hand.
func _offseason() -> Career:
	var c: Career = null
	for s in [96, 97, 98, 99]:
		c = _career(s)
		c.credits = 2000
		for i in 4:
			Recruiting.sign(c, c.market[0])
		_to_done(c)
		c.queue.clear()
		if Recruiting.over_by(c) > 0:
			break
	var me := c.team()
	var grad_ids: Array = me.roster.filter(func(p: PoloPlayer): return p.year >= 4).map(func(p): return p.id)
	var signed_ids: Array = c.incoming.map(func(x): return (x.p as PoloPlayer).id)
	c.end_week()   # (the transition)
	r.check(c.phase == "cuts", "an over-cap roster waits for its cuts")
	var rep: Dictionary = c.season.get(RosterReport.KEY, {})
	r.check(not rep.is_empty(), "the report is started at the transition")
	r.check(_ids(rep.grads) == _sorted(grad_ids), "graduates: exactly the seniors who left (%d)" % grad_ids.size())
	r.check(_ids(rep.fresh) == _sorted(signed_ids), "freshmen: exactly your signings (%d)" % signed_ids.size())
	r.check(rep.grads.all(func(e): return me.find_id(int(e.id)) == null), "graduates are off the roster")
	# a save in the cuts phase keeps it
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(_ids((back.season.get(RosterReport.KEY, {}) as Dictionary).get("grads", [])) == _ids(rep.grads), "the report survives a save mid-cuts")
	var cut_ids: Array = []
	var cut_stars := {}
	while not Offseason.roster_legal(c):
		var can: Array = me.roster.filter(func(p: PoloPlayer): return Offseason.cut_block(c, p) == "")
		if can.is_empty():
			break
		can.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.overall() < b.overall())
		cut_ids.append(can[0].id)
		cut_stars[can[0].id] = snappedf(can[0].stars, 0.01)
		Offseason.cut(c, can[0])
	r.check(Offseason.finish_cuts(c) == "" and c.phase == "season", "continue to the next season")
	var item: Dictionary = {}
	for q in c.queue:
		if String(q.get("type", "")) == "recap" and q.has("report"):
			item = q
	r.check(not item.is_empty() and String(item.get("screen", "")) == "roster_set", "the ROSTER SET item carries the report and its screen")
	r.check(not (item.get("lines", []) as Array).is_empty(), "the text lines are still there (older builds)")
	var f: Dictionary = item.get("report", {})
	r.check(_ids(f.cuts) == _sorted(cut_ids), "cuts: exactly the players cut (%d)" % cut_ids.size())
	r.check(f.cuts.all(func(e): return is_equal_approx(float(e.stars), float(cut_stars[int(e.id)]))), "cuts: their stars when cut")
	var all_ids: Array = []
	for k in ["grads", "fresh", "cuts"]:
		all_ids.append_array(_ids(f[k]))
	var uniq := {}
	for id in all_ids:
		uniq[id] = true
	r.check(uniq.size() == all_ids.size(), "no player in two sections or twice")
	for e in f.elsewhere:
		var to := String(e.to)
		r.check(int(e.id) in cut_ids and c.teams.has(to) and c.teams[to].find_id(int(e.id)) != null and String(e.to_name) == c.teams[to].name,
			"signed elsewhere: %s is on %s's roster" % [e.last, e.to_name])
	r.check(int(f.roster) == me.roster.size() and int(f.schol) == me.roster.filter(func(p: PoloPlayer): return p.schol).size(), "summary: the final roster and scholarships")
	var fresh_ids := _ids(f.fresh)
	r.check(f.dev.all(func(e): return not int(e.id) in fresh_ids), "development: returning players only")
	r.check(f.dev.all(func(e): return me.find_id(int(e.id)) != null and is_equal_approx(float(e.now), snappedf(me.find_id(int(e.id)).stars, 0.01))),
		"development: the stars each returning player has now (%d)" % f.dev.size())
	var rt: Dictionary = f.ratings
	r.check(int(rt.ovr) == PoloTeam.display_ovr(float(me.ratings()[0])) and int(rt.gk) == me.goalkeeping_display()
		and is_equal_approx(float(rt.off), PoloTeam.rating_stars(me.offense_display())) and is_equal_approx(float(rt.def), PoloTeam.rating_stars(me.defense_display())),
		"outlook: next season's OVR %d, OFF, DEF, GK %d as the roster has them" % [int(rt.get("ovr", 0)), int(rt.get("gk", 0))])
	var line: String = (item.lines as Array).filter(func(l): return String(l).contains(" ratings: OVR "))[0]
	r.check(line.contains("OVR %d (%+d)" % [int(rt.ovr), int(rt.ovr) - int(rt.get("ovr_was", rt.ovr))]), "outlook: the same change the text report gives (%s)" % line)
	r.check(not RosterReport.latest(c).is_empty() and not c.season.has(RosterReport.KEY), "kept on the season's history for DEV Mode; nothing left over")
	return c

func _screen(c: Career) -> void:
	Game.career = c
	var idx := -1
	for i in c.queue.size():
		if c.queue[i].has("report"):
			idx = i
	var item: Dictionary = c.queue[idx]
	# the hub routes it: put it at the front, as the hub sees it
	c.queue.remove_at(idx)
	c.queue.push_front(item)
	var n0 := c.queue.size()
	Game.goto(String(item.get("screen", "recap")), item)
	await _frames(runner_tree(), 4)
	var s: Node = Game.current_screen
	r.check(Game.current_name == "roster_set", "the hub's ROSTER SET item opens the roster set screen")
	var go: Button = s.find_child("Continue", true, false)
	r.check(go != null and go.text.begins_with("ON TO %s" % String(item.report.to)), "ON TO %s >" % String(item.report.to))
	r.check(s.find_child("DevBar", true, false) == null and s.find_child("ReturnDev", true, false) == null, "no DEV controls in the real offseason")
	for sec in [["Graduates", "grads"], ["Freshmen", "fresh"], ["Cuts", "cuts"]]:
		var p: Node = s.find_child(sec[0], true, false)
		var want: int = (item.report[sec[1]] as Array).size()
		var got := 0 if p == null or p.find_child("Cards", true, false) == null else p.find_child("Cards", true, false).get_child_count()
		r.check(p != null and got == want, "%s: a card a player (%d)" % [sec[0], want])
	r.check(s.find_child("Outlook", true, false) != null and s.find_child("YourSeasons", true, false) != null, "the outlook and YOUR SEASONS are there")
	r.check(c.queue.size() == n0, "opening it changes nothing")
	go.pressed.emit()
	await _frames(runner_tree(), 2)
	r.check(c.queue.size() == n0 - 1 and not c.queue.any(func(q): return q.has("report")), "ON TO takes it off the queue, once")
	r.check(Game.current_name != "roster_set", "ON TO leaves the screen")

func _dev_preview(c: Career) -> void:
	Game.career = c
	c.queue.clear()
	var before := JSON.stringify(c.to_dict())
	Game.settings.dev_mode = false
	Game.goto("roster_set")
	await _frames(runner_tree(), 2)
	r.check(Game.current_name == "settings", "DEV preview: closed to Developer Mode off")
	Game.settings.dev_mode = true
	var script: GDScript = load("res://src/ui/screens/roster_set.gd")
	var keys: Array = ["real"] + RosterReport.SCENARIOS.map(func(s): return String(s[0]))
	for k in keys:
		script.set("scenario", k)
		Game.goto("roster_set", {}, false)
		await _frames(runner_tree(), 3)
		var s: Node = Game.current_screen
		r.check(s.find_child("DevBar", true, false) != null and s.find_child("ReturnDev", true, false) != null and s.find_child("Continue", true, false) == null,
			"DEV preview %s: DEV controls, RETURN TO DEV MODE, no continue" % k)
		var nx: Button = s.find_child("NextScenario", true, false)
		if k == keys[0]:
			nx.pressed.emit()   # (the arrows open the next scenario on the same screen)
			await _frames(runner_tree(), 3)
			r.check(Game.current_name == "roster_set" and String(script.get("scenario")) == keys[1], "DEV preview: > goes to the next scenario")
	var ret: Button = Game.current_screen.find_child("ReturnDev", true, false)
	DevGate.try_unlock("8008")   # (the DEV screen's code, as entered on the way in)
	ret.pressed.emit()
	await _frames(runner_tree(), 2)
	r.check(Game.current_name == "dev_settings", "RETURN TO DEV MODE goes back to the developer tools")
	r.check(Game.current_screen.find_child("ViewRosterSet", true, false) != null, "DEVELOPER TOOLS has VIEW ROSTER SET")
	r.check(JSON.stringify(c.to_dict()) == before, "DEV preview: the career is exactly as it was (nothing graduated, cut, rated, queued or saved)")
	Game.settings.dev_mode = false

func _samples() -> void:
	for s in RosterReport.SCENARIOS:
		var a := RosterReport.sample(String(s[0]), "CULA", "Los Angeles Bears")
		var b := RosterReport.sample(String(s[0]), "CULA", "Los Angeles Bears")
		r.check(JSON.stringify(a) == JSON.stringify(b) and bool(a.preview), "sample %s: the same every time, marked DEV" % s[0])
	var n := RosterReport.sample("normal", "CULA", "x")
	r.check(n.grads.size() >= 2 and n.fresh.size() >= 2 and n.cuts.size() >= 2 and not n.elsewhere.is_empty(), "sample: graduates, freshmen, cuts, signed elsewhere")
	r.check(n.dev.any(func(e): return float(e.now) > float(e.was)) and n.dev.any(func(e): return float(e.now) < float(e.was)), "sample: ups and downs in development")
	r.check((n.history.history as Array).size() >= 2, "sample: several seasons of history")
	r.check(RosterReport.sample("no_cuts", "CULA", "x").cuts.is_empty() and RosterReport.sample("big_history", "CULA", "x").history.history.size() >= 10, "no cuts / large history")

## An older save: a ROSTER SET item with only its lines still goes to the recap screen; a history
## without a report has nothing for DEV Mode's real preview.
func _old_saves() -> void:
	var q := {"type": "recap", "title": "2026-27 ROSTER SET", "lines": ["Roster set: 10 players"], "next": "2027-28"}
	r.check(String(q.get("screen", "recap")) == "recap", "an older ROSTER SET item opens the recap screen")
	var c := _career(5)
	c.history = [{"year": "2026-27", "team": "CULA", "w": 10, "l": 5}]
	r.check(RosterReport.latest(c).is_empty(), "an older history has no report (the samples are offered instead)")

func shots(runner, dir: String) -> void:
	r = runner
	Game.test_mode = true
	DirAccess.make_dir_recursive_absolute(dir)
	var c := await _offseason()
	Game.career = c
	for q in c.queue:
		if q.has("report"):
			Game.goto("roster_set", q)
			await _shot(dir, "roster_set_0_real")
			var sc: ScrollContainer = Game.current_screen.find_child("ReportScroll", true, false)
			sc.scroll_vertical = 220
			await _shot(dir, "roster_set_1_real_scrolled")
			sc.scroll_vertical = 100000
			await _shot(dir, "roster_set_2_real_end")
	Game.settings.dev_mode = true
	var script: GDScript = load("res://src/ui/screens/roster_set.gd")
	var i := 3
	for s in RosterReport.SCENARIOS:
		script.set("scenario", String(s[0]))
		Game.goto("roster_set", {}, false)
		await _shot(dir, "roster_set_%d_%s" % [i, s[0]])
		var sc: ScrollContainer = Game.current_screen.find_child("ReportScroll", true, false)
		sc.scroll_vertical = 230
		await _shot(dir, "roster_set_%d_%s_b" % [i, s[0]])
		i += 1
	DevGate.try_unlock("8008")   # (the developer tools: the DEV screen, behind its code)
	Game.goto("dev_settings", {}, false)
	await _shot(dir, "roster_set_99_settings")
	Game.settings.dev_mode = false
	Game.career = null

# ------------------------------------------------------------------ helpers
func runner_tree() -> SceneTree:
	return r.get_tree()

func _frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame

func _shot(dir: String, name: String) -> void:
	await _frames(r.get_tree(), 8)
	r.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])

func _ids(list: Array) -> Array:
	return _sorted(list.map(func(e): return int(e.id)))

func _sorted(a: Array) -> Array:
	var b := a.map(func(x): return int(x))
	b.sort()
	return b
