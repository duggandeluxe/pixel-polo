extends RefCounted
## Championship Elimination: knocked out of the NCSA (or left out of it), the OH NO! screen once,
## the season so far, the SEASON OVER hub (RECRUITING, SIM TO OFFSEASON), the sim to the
## off-season once, saves old and new.
##   godot --headless --path game -- --test elimination
##   godot --path game --resolution 480x270 -- --test elimination_png <dir>

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

## A career played by the sim until it's knocked out (or the season ends). Never a conference
## round counts as an elimination on the way.
func _to_elimination(school: String, seed_value: int) -> Career:
	var c := Career.new_game(school, "A", "B", seed_value)
	c.sandbox = true
	var conf_ok := true
	var guard := 400
	while c.phase == "season" and not c.is_eliminated() and guard > 0:
		guard -= 1
		if c.week < c.schedule.size() and String(c.cur().kind).begins_with("conf_") and c.knocked_out():
			conf_ok = false
		if c.has_game():
			c.sim_my_game()
			c.close_postgame()
		else:
			c.sim_week_without_me()
			c.end_week()
	r.check(conf_ok, "conference tournament rounds never end a season by themselves (%s)" % school)
	return c

func _weakest() -> String:
	var s: Array = Colleges.SCHOOLS.duplicate()
	s.sort_custom(func(a, b): return float(a.ovr) < float(b.ovr))
	return String(s[0].short)

func _strongest() -> String:
	var s: Array = Colleges.SCHOOLS.duplicate()
	s.sort_custom(func(a, b): return float(a.ovr) > float(b.ovr))
	return String(s[0].short)

func run(runner) -> void:
	r = runner
	print("championship elimination")
	Store.reset_for_tests()
	var lab = load("res://src/ui/screens/elim_lab.gd")
	# ---- the sandbox report's own checks, both ways a season can end
	for strong in [false, true]:
		for seed_value in [11, 12]:
			var lines: Array = lab.sandbox(strong, seed_value)
			var fails: Array = lines.filter(func(l): return String(l).begins_with("FAIL"))
			r.check(fails.is_empty(), "sandbox %s seed %d: %s" % ["strong" if strong else "weak", seed_value, " / ".join(fails) if not fails.is_empty() else "all OK (%s)" % String(lines[2] if lines.size() > 2 else "")])
	# ---- a weak program: left out of the NCSA
	var c := _to_elimination(_weakest(), 21)
	r.check(c.is_eliminated(), "1: a weak program is eliminated once the NCSA field is drawn without it")
	r.check(c.season_state == Career.STATE_ELIMINATED and c.elim_pending(), "2, 13: ELIMINATED, the OH NO! screen still to come")
	r.check(String(c.elim.get("round", "")) == "NOT SELECTED FOR THE NCSA CHAMPIONSHIP", "14: no qualification reads as not selected (%s)" % String(c.elim.get("round", "")))
	r.check(c.coach_pending.is_empty(), "8: no decision waits on a next game")
	r.check(c.next_game().get("opp", "") == "", "1: no game scheduled for you")
	# ---- save and load: the state stays, and an old save works it out without replaying
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var back := Career.from_dict(d)
	r.check(back.is_eliminated() and back.elim_pending(), "13: elimination (and the unseen screen) survive a save")
	d.erase("season_state")
	d.erase("elim")
	var old := Career.from_dict(d)
	r.check(old.is_eliminated() and not old.elim_pending(), "13, 14: an older save already out loads eliminated, no OH NO! replay")
	# ---- SIM TO OFFSEASON (the eliminated state, kept for older saves and the DEV preview): on a copy
	var market := back.market.size()
	var refreshes := back.refreshes
	var signed := back.incoming.size()
	r.check(back.sim_to_offseason(), "6: SIM TO OFFSEASON reaches the off-season")
	r.check(not back.sim_to_offseason(), "13: and only once")
	r.check(back.phase == "done" and back.season_state == Career.STATE_OFFSEASON, "6, 13: OFFSEASON")
	r.check(back.market.size() == market and back.refreshes == refreshes and back.incoming.size() == signed, "9: the recruiting board is as it was")
	# ---- the screens: the hub runs the rest of the season at once (the automatic postseason advance)
	Game.career = c
	for q in c.upgrades_due():
		Development.ai_spend(q)
	Game.goto("hub")
	await _frames(4)
	r.check(c.phase == "done" and c.season_state == Career.STATE_OFFSEASON, "6: no SIM TO OFFSEASON to press: the hub sims to the off-season")
	r.check(String(c.season.get("champion", "")) != "", "12: the NCSA champion is decided")
	r.check(c.history.size() == 1, "12: the season in the history once")
	r.check(c.queue.any(func(q): return String(q.type) == "recap"), "12: the final season review is queued")
	r.check(Game.current_name == "season_over", "2: the hub sends you to OH NO! first (%s)" % Game.current_name)
	var so = Game.current_screen
	var btn: Button = so.find_child("ViewSeasonReview", true, false)
	r.check(btn != null and btn.text.begins_with("VIEW SEASON REVIEW"), "2: the big yellow VIEW SEASON REVIEW")
	btn.pressed.emit()
	await _frames(4)
	r.check(not c.elim_pending(), "2, 12: seen once")
	r.check(Game.current_name == "recap" and not Game.current_screen.live, "3: the season's own review opens (%s)" % Game.current_name)
	# the SEASON OVER hub lives on as the DEV preview (elim_lab)
	Game.settings["dev_mode"] = true
	Game.career = old   # (still eliminated, mid-NCSA: the preview draws what an older save would show)
	Game.goto("hub", {"elim_preview": true})
	await _frames(4)
	var hub = Game.current_screen
	r.check(hub.find_child("SeasonOver", true, false) != null, "4: SEASON OVER (DEV preview)")
	r.check(hub.find_child("Nav_recruiting", true, false) != null and hub.find_child("Nav_coaching", true, false) == null, "5: RECRUITING replaces COACHING")
	var play: Button = hub.find_child("PlayButton", true, false)
	r.check(play != null and play.text.begins_with("SIM TO OFFSEASON"), "6: SIM TO OFFSEASON (%s)" % (play.text if play != null else "none"))
	Game.settings["dev_mode"] = false
	Game.career = c
	# ---- next season: back to normal
	c.queue.clear()
	c.end_week()   # (NEXT SEASON: the transition)
	if c.phase == "cuts":
		for p in c.team().roster.duplicate():
			if Offseason.roster_legal(c):
				break
			Offseason.cut(c, p)
		Offseason.finish_cuts(c)
	r.check(c.phase == "season" and c.season_state == Career.STATE_ACTIVE and c.elim.is_empty(), "13: the next season starts ACTIVE")
	c.queue.clear()
	for q in c.upgrades_due():
		Development.ai_spend(q)
	Game.goto("hub")
	await _frames(4)
	r.check(Game.current_screen.find_child("Nav_coaching", true, false) != null, "5: COACHING is back next season")
	await _title()
	Game.career = null
	Game.goto("title")
	await _frames(2)

## Winning it all: the CHAMPIONS! screen once (never OH NO!), then the season's review.
func _title() -> void:
	var c: Career = null
	for seed_value in [31, 32, 33, 34, 35, 36, 37, 38]:
		var x := _to_elimination(_strongest(), seed_value)
		if String(x.season.get("champion", "")) == x.school:
			c = x
			break
	if c == null:
		print("  (no title in eight seasons: the CHAMPIONS! checks are skipped)")
		return
	r.check(c.champ_pending() and not c.elim_pending(), "title: CHAMPIONS! queued, not OH NO!")
	r.check(not c.is_eliminated() and c.season_state == Career.STATE_OFFSEASON, "title: no SEASON OVER hub, straight to the off-season")
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(back.champ_pending(), "title: survives a save")
	for q in c.upgrades_due():
		Development.ai_spend(q)
	Game.career = c
	Game.goto("hub")
	await _frames(4)
	r.check(Game.current_name == "champions", "title: the hub opens CHAMPIONS! (%s)" % Game.current_name)
	var btn: Button = Game.current_screen.find_child("ViewSeasonReview", true, false)
	r.check(btn != null, "title: VIEW SEASON REVIEW")
	while not c.queue.is_empty() and String(c.queue[0].type) != "recap":
		c.queue.pop_front()   # (what's queued ahead of the review: its own shows)
	btn.pressed.emit()
	await _frames(4)
	r.check(not c.champ_pending(), "title: seen once")
	r.check(Game.current_name == "recap" and not Game.current_screen.live, "title: the season's own review (%s)" % Game.current_name)
	Game.goto("hub")
	await _frames(4)
	r.check(Game.current_name != "champions", "title: never twice")

## PNGs: the OH NO! screen's frames, the live review, the SEASON OVER hub.
static func shots(runner, dir: String) -> void:
	var t := new()
	t.r = runner
	Store.reset_for_tests()
	DirAccess.make_dir_recursive_absolute(dir)
	var c := t._to_elimination(t._weakest(), 21)
	Game.career = c
	var lab = load("res://src/ui/screens/elim_lab.gd")
	var dev_was = Game.settings.get("dev_mode", false)
	Game.settings["dev_mode"] = true   # (in memory only: the previews need it; never saved)
	for kind in ["nat_qf", "missed"]:
		Game.goto("season_over", {"preview": true, "model": lab.sample(c, kind)})
		await t._frames(2)
		var so = Game.current_screen
		so.set_process(false)
		for at in [0.3, 0.8, 1.5, 2.4, 4.0]:
			so.t = at
			so.go_btn.modulate.a = clampf((at - 2.6) / 0.3, 0.0, 1.0)
			so.art.queue_redraw()
			await t._frames(2)
			runner.get_viewport().get_texture().get_image().save_png("%s/oh_no_%s_%.1f.png" % [dir, kind, at])
	for kind in ["double", "so"]:
		Game.goto("champions", {"preview": true, "model": lab.champ_sample(c, kind)})
		await t._frames(2)
		var ch = Game.current_screen
		ch.set_process(false)
		for at in [0.5, 1.4, 2.3, 2.62, 2.75, 3.0, 3.6, 4.0, 5.2, 8.0]:
			ch.t = at
			ch.go_btn.modulate.a = clampf((at - ch.TEXT_T) / 0.3, 0.0, 1.0)
			ch.art.queue_redraw()
			await t._frames(2)
			runner.get_viewport().get_texture().get_image().save_png("%s/champ_%s_%.1f.png" % [dir, kind, at])
	c.elim["shown"] = true
	c.queue.clear()
	for q in c.upgrades_due():
		Development.ai_spend(q)
	Game.goto("recap", {"live": true})
	await t._frames(4)
	runner.get_viewport().get_texture().get_image().save_png(dir + "/live_review.png")
	var sc: ScrollContainer = Game.current_screen.find_child("ReviewScroll", true, false)
	if sc != null:
		sc.scroll_vertical = 100000
		await t._frames(3)
		runner.get_viewport().get_texture().get_image().save_png(dir + "/live_review_end.png")
	Game.goto("hub")
	await t._frames(4)
	runner.get_viewport().get_texture().get_image().save_png(dir + "/season_over_hub.png")
	Game.current_screen._sim_offseason()
	await t._frames(3)
	runner.get_viewport().get_texture().get_image().save_png(dir + "/sim_confirm.png")
	Game.goto("training")
	await t._frames(3)
	runner.get_viewport().get_texture().get_image().save_png(dir + "/training.png")
	Game.settings["dev_mode"] = dev_was
	print("shots in ", dir)
