extends RefCounted
## THE ROAD TO GLORY: the scrolling school cards, five tiers opened by career achievements, the
## permanent profile, locked schools refused everywhere, the notifications, old saves. The
## numbered checks follow the spec's REQUIRED TESTING list.
##   godot --headless --path game -- --test glory
##   godot --path game -- --test glory_png <dir>   (shots, and the T10 layouts: needs a window)

const DIR := "user://test_glory/"

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("road to glory")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	_new_profile()
	await _cards()
	await _regroup()
	_logos()
	_five_wins()
	_conf_final()
	_titles()
	await _locked()
	_persistence()
	_existing_save()
	await _layout()
	_nonsequential()
	_duplicates()
	await _notifications()
	_migration()
	Game.progress = null
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

# ------------------------------------------------------------------ helpers
## The five schools with the lowest original overall, the school order breaking ties.
func _bottom(n: int) -> Array:
	var order := Progression.by_rating()
	return order.slice(order.size() - n).map(func(s): return String(s.short))

func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b

## The picker's group headers as "TITLE COUNT".
func _heads(scr) -> Array:
	return scr.list.get_children().filter(func(n): return n.name.begins_with("Header")).map(func(n):
		return " ".join(n.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)))

## True if `order` runs strongest first within each group (open, then each locked tier), by the
## teams' actual overall (the dynasty setup's rosters).
func _groups_desc(order: Array, p: Progression, teams: Dictionary) -> bool:
	for i in range(1, order.size()):
		var a: String = order[i - 1]
		var b: String = order[i]
		var ga := 0 if p.is_unlocked(a) else p.tier_of(a)
		var gb := 0 if p.is_unlocked(b) else p.tier_of(b)
		if gb < ga or (ga == gb and (teams[b] as PoloTeam).team_overall(false) > (teams[a] as PoloTeam).team_overall(false) + 0.000001):
			return false
	return true

## Simulates your games until `stop` says so (or the season ends). Returns how many were played.
func _sim_until(c: Career, stop: Callable, max_weeks: int = 40) -> int:
	var n := 0
	var y := c.year
	var guard := 0
	while c.year == y and guard < max_weeks and not c.in_offseason():
		guard += 1
		while c.has_game():
			c.sim_my_game()
			n += 1
			if stop.call():
				return n
		c.queue = c.queue.filter(func(q): return String(q.type) == "achievement")
		for p in c.team().roster:
			Development.ai_spend(p)   # (the upgrades the game makes you spend before the next game)
		c.end_week()
	return n

func _scratch() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + f))

func _queued(c: Career) -> Array:
	return c.queue.filter(func(q): return String(q.type) == "achievement").map(func(q): return String(q.id))

## A played result in round `kind` for your school: `won` or not. Returns the game.
func _force(c: Career, kind: String, won: bool) -> Dictionary:
	for rd in c.schedule:
		if rd.kind == kind:
			var opp := "CULA" if c.school != "CULA" else "CUSC"
			var g := {"h": c.school, "a": opp, "r": {"s": [9, 4] if won else [4, 9], "so": [], "w": 0 if won else 1}}
			rd.games = [g]
			return g
	return {}

# ------------------------------------------------------------------ T1
func _new_profile() -> void:
	var p := Progression.fresh()
	var low := _bottom(5)
	r.check(p.unlocked.size() == 5, "T1: a new profile has exactly five schools unlocked (%d)" % p.unlocked.size())
	r.check(_sorted(p.unlocked) == _sorted(low), "T1: they're the five lowest-rated programs %s" % str(p.unlocked))
	var ovr_open: Array = p.unlocked.map(func(id): return int(Colleges.school(id).ovr))
	var ovr_shut: Array = Colleges.SCHOOLS.filter(func(s): return not s.short in p.unlocked).map(func(s): return int(s.ovr))
	r.check(ovr_open.max() <= ovr_shut.min(), "T1: every locked school is rated at least as high as every open one")
	r.check(Colleges.SCHOOLS.filter(func(s): return not p.is_unlocked(s.short)).size() == 25, "T1: the other 25 are locked")
	var sizes := []
	for t in range(1, 6):
		sizes.append(p.schools_in_tier(t).size())
	r.check(sizes == [5, 7, 7, 7, 4], "T1: tiers of 5, 7, 7, 7 and 4 schools %s" % str(sizes))
	var top4: Array = Progression.by_rating().slice(0, 4).map(func(s): return String(s.short))
	r.check(_sorted(p.schools_in_tier(5)) == _sorted(top4) and _sorted(top4) == _sorted(["CULA", "CUSC", "STAM", "ALC"]), "T1: the four highest-rated programs are Tier 5 %s" % str(top4))
	r.check(p.done.is_empty() and p.tiers.size() == 30, "T1: no achievements yet, all 30 schools have a tier")
	var all_open := true
	for s in Colleges.SCHOOLS:
		all_open = all_open and float(s.ovr) == float(Colleges.school(s.short).ovr)
	r.check(all_open, "T1: no school's rating was touched")

# ------------------------------------------------------------------ T2
func _cards() -> void:
	Game.career = null
	Game.progress = Progression.fresh()
	Game.goto("new_career")
	for _i in 3:
		await r.get_tree().process_frame
	var scr = Game.current_screen
	r.check(scr.cards.size() == 30, "T2: 30 school cards (%d)" % scr.cards.size())
	var grids: Array = scr.list.get_children().filter(func(n): return n is GridContainer)
	r.check(grids.map(func(g): return g.get_child_count()).reduce(func(a, b): return a + b, 0) == 30, "T2: the grid holds the 30 cards (under the tier headers)")
	var order: Array = scr.card_order()
	var same := _sorted(order.slice(0, 5)) == _sorted(_bottom(5))
	var at := 5
	for t in range(2, 6):
		var ids: Array = Game.progress.schools_in_tier(t)
		same = same and _sorted(order.slice(at, at + ids.size())) == _sorted(ids)
		at += ids.size()
	r.check(same, "T2 (T39): the five open schools, then Tier 2, 3, 4 and 5's locked ones %s" % str(order.slice(0, 5)))
	r.check(_groups_desc(order, Game.progress, scr.preview.teams), "T2 (T39): strongest first within each group, by the generated rosters' overall")
	r.check(_heads(scr) == ["AVAILABLE TEAMS 5", "LOCKED — WIN 5 GAMES 7", "LOCKED — REACH CONFERENCE CHAMPIONSHIP 7", "LOCKED — WIN CONFERENCE CHAMPIONSHIP 7", "LOCKED — WIN NATIONAL CHAMPIONSHIP 4"], "T2 (T39): a header over each group %s" % str(_heads(scr)))
	var wrong: Array = []
	for id in scr.cards:
		var card: Control = scr.cards[id]
		var t: PoloTeam = scr.preview.teams[id]
		var texts: Array = card.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
		var logo: bool = card.find_child("Logo", true, false) != null
		var off: Control = card.find_child("StarsOFF", true, false)
		var dfn: Control = card.find_child("StarsDEF", true, false)
		var ok: bool = Colleges.place(id).to_upper() in texts and String(Colleges.school(id).mascot).to_upper() in texts \
			and Colleges.conf_abbr(Colleges.school(id).conf) in texts \
			and off != null and float(off.get_meta("stars")) == scr.card_stars(t.offense_display()) \
			and dfn != null and float(dfn.get_meta("stars")) == scr.card_stars(t.defense_display()) \
			and "OFF" in texts and "DEF" in texts and logo \
			and (card.find_child("Lock", true, false) != null) == (not Game.progress.is_unlocked(id)) and not id in texts
		if not ok:
			wrong.append(id)
	r.check(wrong.is_empty(), "T2: every card shows its logo, name, conference, OFF and DEF stars and lock status %s" % str(wrong))
	var reqs := {}
	for id in scr.cards:
		if not Game.progress.is_unlocked(id):
			reqs[Game.progress.tier_of(id)] = String(Game.progress.requirement(id).req)
	r.check(reqs == {2: "WIN 5 GAMES IN ONE SEASON", 3: "REACH A CONFERENCE CHAMPIONSHIP", 4: "WIN A CONFERENCE CHAMPIONSHIP", 5: "WIN A NATIONAL CHAMPIONSHIP"}, "T2: each locked tier names its achievement %s" % str(reqs))
	r.check(Game.progress.is_unlocked(scr.pick) and scr.pick == order[0], "T2: your first pick is the strongest open school, the top card (%s)" % scr.pick)
	var bar: VScrollBar = scr.list_scroll.get_v_scroll_bar()
	r.check(bar.max_value - bar.page > 0 and scr.list_scroll.scroll_vertical == 0, "T2: a new player's list opens at the top, on AVAILABLE TEAMS (%d)" % scr.list_scroll.scroll_vertical)
	r.check(_bottom(5).slice(0, scr.columns()).all(func(id): return _in_view(scr, id)) or order.slice(0, scr.columns()).all(func(id): return _in_view(scr, id)), "T2: the first row of starting programs is in view")
	r.check(scr.list_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and scr.list_scroll is TouchScroll, "T2: the list scrolls by touch, never sideways")
	# no panel: the cards are the whole choice
	var all_text: Array = scr.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	r.check(scr.find_child("SchoolLocked", true, false) == null and not all_text.any(func(tx): return tx in ["OVERALL RATING", "GOALKEEPING", "HOME POOL", "COLORS", "HOME"]), "T2: no school panel: no OVR, GK, home, pool or colours")
	r.check(not all_text.any(func(tx): return "UNIVERSITY" in tx.to_upper() or "COLLEGE" in tx.to_upper() or "ACADEMY" in tx.to_upper() or "INSTITUTE" in tx.to_upper()), "T2: no university names")
	r.check(str(scr.preview.teams.CULA.overall_display()) == "91", "T2: the Los Angeles Bears are still OVR 91")
	# scrolling keeps its place while picking
	scr.list_scroll.scroll_vertical = 120
	scr._pick(order[1])
	await r.get_tree().process_frame
	r.check(scr.list_scroll.scroll_vertical == 120, "T2: picking a school keeps the scroll position")
	Game.goto("title")
	await r.get_tree().process_frame

# ------------------------------------------------------------------ T40, T41: the list regroups
func _regroup() -> void:
	# five wins: Tier 2 joins the open group, sorted in with Tier 1
	Game.progress = Progression.fresh()
	Game.progress.award(["five_wins"])
	Game.goto("new_career")
	for _i in 3:
		await r.get_tree().process_frame
	var scr = Game.current_screen
	var order: Array = scr.card_order()
	var open: Array = order.slice(0, 12)
	r.check(open.all(func(id): return Game.progress.is_unlocked(id)) and Game.progress.unlocked.size() == 12, "T40: the 12 open schools are the first 12 cards")
	r.check(_groups_desc(order, Game.progress, scr.preview.teams), "T40: the 12 sorted together strongest first, then each locked tier strongest first")
	r.check(_heads(scr) == ["AVAILABLE TEAMS 12", "LOCKED — REACH CONFERENCE CHAMPIONSHIP 7", "LOCKED — WIN CONFERENCE CHAMPIONSHIP 7", "LOCKED — WIN NATIONAL CHAMPIONSHIP 4"], "T40: Tier 2's locked group is gone %s" % str(_heads(scr)))
	r.check(scr.pick == order[0] and Game.progress.tier_of(order[0]) == 2, "T40: your first pick is the strongest open school, now a Tier 2 one (%s)" % scr.pick)
	# out of order: Tier 4 before Tier 3
	Game.progress.award(["conf_champ"])
	Game.goto("new_career")
	for _i in 3:
		await r.get_tree().process_frame
	scr = Game.current_screen
	order = scr.card_order()
	var tiers: Array = order.slice(0, 19).map(func(id): return Game.progress.tier_of(id))
	r.check(order.slice(0, 19).all(func(id): return Game.progress.is_unlocked(id)) and 4 in tiers and not 3 in tiers, "T41: Tiers 1, 2 and 4 open together, Tier 3 not")
	r.check(_groups_desc(order, Game.progress, scr.preview.teams), "T41: sorted together by overall, the locked tiers after in order")
	r.check(_heads(scr) == ["AVAILABLE TEAMS 19", "LOCKED — REACH CONFERENCE CHAMPIONSHIP 7", "LOCKED — WIN NATIONAL CHAMPIONSHIP 4"], "T41: the locked groups left are Tier 3 then Tier 5 %s" % str(_heads(scr)))
	var groups := Game.progress.picker_groups()
	r.check(groups == Game.progress.picker_groups(), "T15: the same groups every time")
	Game.goto("title")
	await r.get_tree().process_frame

# ------------------------------------------------------------------ T42, T43: logos and names
func _logos() -> void:
	var missing: Array = []
	var bad: Array = []
	var seen := {}
	for s in Colleges.SCHOOLS:
		var id := String(s.short)
		for tag in TeamLogo.ART_BOXES:
			var path := TeamLogo.ART_PATH % [id, tag]
			if not ResourceLoader.exists(path):
				missing.append(path)
				continue
			var img: Image = (load(path) as Texture2D).get_image()
			var b: Vector2i = TeamLogo.ART_BOXES[tag]
			var fits := img.get_width() <= b.x and img.get_height() <= b.y and (img.get_width() == b.x or img.get_height() == b.y)
			var sharp := true
			for y in img.get_height():
				for x in img.get_width():
					var al := img.get_pixel(x, y).a
					sharp = sharp and (al == 0.0 or al == 1.0)
			if not fits or not sharp:
				bad.append(path)
			if tag == "60":
				seen[img.get_data()] = id
	r.check(missing.is_empty(), "T42: every school has its artwork at every size %s" % str(missing))
	r.check(bad.is_empty(), "T42: each fills its box without stretching, edges sharp (no half-transparent pixels) %s" % str(bad))
	r.check(seen.size() == 30, "T42: 30 different logos, none shared (%d)" % seen.size())
	var stam := Colleges.school("STAM")
	r.check(TeamLogo.art(stam, Vector2i(60, 60)) != null, "T42: the Pacific Grove Redwoods draw their redwood-and-PG artwork")
	var c := Career.new_game("HURST", "A", "B", 5)
	var used := true
	for id in ["CULA", "HURST", "SJCU"]:
		var t: PoloTeam = c.teams[id]
		for sz in [[TeamLogo.SMALL, 0], [TeamLogo.MEDIUM, 0], [TeamLogo.LARGE, 0], [TeamLogo.LARGE, 3]]:
			var b := TeamLogo.box(sz[0], sz[1])
			var tex := TeamLogo.art(t, b)
			used = used and tex != null and tex.get_width() <= b.x and tex.get_height() <= b.y
	r.check(used, "T42: a career's teams draw their artwork at every size the screens use")
	var colours := Colleges.SCHOOLS.all(func(s): return (c.teams[s.short] as PoloTeam).c1 == Color(String(s.c1)) and (c.teams[s.short] as PoloTeam).c2 == Color(String(s.c2)))
	r.check(colours, "T25: team colours untouched")
	var uni: Array = Colleges.SCHOOLS.filter(func(s): return s.has("school") or "University" in String(s.name) or "College" in String(s.name)).map(func(s): return s.short)
	r.check(uni.is_empty(), "T43: no university or college names kept %s" % str(uni))
	r.check(Colleges.team_name("PRIN") == "New Jersey Bengals" and Colleges.team_name("STAM") == "Pacific Grove Redwoods" and Colleges.team_name("BROW") == "Providence Grizzlies", "T43: place names kept (New Jersey, Pacific Grove, Providence)")
	var hired: Dictionary = c.queue.filter(func(q): return String(q.get("title", "")).begins_with("WELCOME"))[0] if c.queue.any(func(q): return String(q.get("title", "")).begins_with("WELCOME")) else {}
	r.check(String(hired.get("text", "")).begins_with("The Erie Lakehawks have hired you"), "T43: the welcome names the team, not a university")

# ------------------------------------------------------------------ T3
func _five_wins() -> void:
	Game.progress = Progression.fresh()
	var c := Career.new_game("CULA", "A", "B", 41)
	Game.career = c
	c.queue.clear()
	var seen := {"at": -1, "early": false}   # (a lambda can't assign the function's locals)
	_sim_until(c, func():
		var w := Progression.season_wins(c.school, c.schedule)
		if w < Progression.SEASON_WINS and "five_wins" in Game.progress.done:
			seen.early = true
		if w >= Progression.SEASON_WINS and int(seen.at) < 0 and "five_wins" in Game.progress.done:
			seen.at = w
		return w >= Progression.SEASON_WINS)
	r.check(int(seen.at) == Progression.SEASON_WINS and not seen.early, "T3: the five-win achievement comes with the fifth win, not before (at %d)" % int(seen.at))
	r.check("five_wins" in Game.progress.done, "T3: Tier 2 achievement awarded")
	var t2: Array = Game.progress.schools_in_tier(2)
	r.check(t2.size() == 7 and t2.all(func(id): return Game.progress.is_unlocked(id)) and Game.progress.unlocked.size() == 12, "T3: seven Tier 2 schools unlocked (12 open)")
	r.check(_queued(c) == ["five_wins"], "T3: one notification queued for after the game %s" % str(_queued(c)))
	var q: Dictionary = c.queue.filter(func(q): return String(q.type) == "achievement")[0]
	r.check(int(q.count) == 7 and String(q.title) == "FIVE-WIN SEASON", "T3: it says 7 new programs (%d, %s)" % [int(q.count), q.title])
	var d := Progression.from_dict(JSON.parse_string(JSON.stringify(Game.progress.to_dict())))
	r.check("five_wins" in d.done and d.unlocked.size() == 12, "T3: and it's in the saved profile")
	# wins from two seasons never add up: four last season and one this season earn nothing
	var p := Progression.fresh()
	r.check(p.reconstruct([], [{"w": 4, "l": 12}]).is_empty() and not "five_wins" in p.done, "T3: a 4-win season earns nothing")
	var c2 := Career.new_game("HURST", "A", "B", 3)
	c2.history = [{"year": "2025-26", "team": "HURST", "w": 4, "l": 12}]
	var one := 0
	for rd in c2.schedule:
		for g in rd.games:
			if (g.h == c2.school or g.a == c2.school) and one < 1:
				g.r = {"s": [9, 1], "so": [], "w": 0 if g.h == c2.school else 1}
				one += 1
	r.check(p.reconstruct_career(c2).is_empty() and Progression.season_wins(c2.school, c2.schedule) == 1, "T3: 4 wins last season + 1 this season are not five in one season")
	# a season ends: the next one counts from zero
	var c3 := Career.new_game("CULA", "A", "B", 41)
	_sim_until(c3, func(): return false)
	var w_end := Progression.season_wins(c3.school, c3.schedule)
	var guard := 0
	while c3.year == Career.START_YEAR and guard < 30:
		guard += 1
		c3.queue.clear()
		c3.end_week()
	r.check(w_end >= 5 and Progression.season_wins(c3.school, c3.schedule) == 0, "T3: a new season's wins start at 0 (last season %d)" % w_end)
	Game.career = null

# ------------------------------------------------------------------ T4, T5
## Real seasons, simulated: the conference final achievements come exactly when the schedule shows
## your school played (and won) its conference final.
func _conf_final() -> void:
	var reached := 0
	var won := 0
	var missed := 0
	var agree := true
	for seed in [11, 12, 13, 14, 15, 16]:
		Game.progress = Progression.fresh()
		var school := "CULA" if seed % 2 == 0 else "STAM"
		if seed == 15:
			school = "HURST"   # (a weak school: it can miss the final)
		var c := Career.new_game(school, "A", "B", seed)
		Game.career = c
		_sim_until(c, func(): return c.week >= 13 or c.in_offseason())
		var played := false
		var champ := false
		for g in c.schedule[12].games:
			if g.r != null and (g.h == school or g.a == school):
				played = true
				champ = Schedule.winner(g) == school
		reached += 1 if played else 0
		won += 1 if champ else 0
		missed += 0 if played else 1
		agree = agree and (("conf_final" in Game.progress.done) == played) and (("conf_champ" in Game.progress.done) == champ)
		agree = agree and ((school in c.season.get("conf_champs", [])) == champ)
		if played:
			var t3: Array = Game.progress.schools_in_tier(3)
			agree = agree and t3.size() == 7 and t3.all(func(id): return Game.progress.is_unlocked(id))
		if champ:
			var t4: Array = Game.progress.schools_in_tier(4)
			agree = agree and t4.size() == 7 and t4.all(func(id): return Game.progress.is_unlocked(id))
			agree = agree and "conf_final" in _queued(c) and "conf_champ" in _queued(c)
		agree = agree and not "nat_champ" in Game.progress.done
	r.check(agree, "T4/T5: in six simulated seasons the conference achievements match the conference finals played and won")
	r.check(reached > 0 and won > 0, "T4/T5: (seen: %d finals reached, %d won, %d missed)" % [reached, won, missed])
	# reaching it is enough for Tier 3; losing it opens nothing more
	Game.progress = Progression.fresh()
	var c := Career.new_game("HURST", "A", "B", 5)
	_force(c, "conf_final", false)
	c.check_glory()
	r.check("conf_final" in Game.progress.done and not "conf_champ" in Game.progress.done, "T4: a lost conference final still earns Tier 3, not Tier 4")
	r.check(Game.progress.schools_in_tier(3).all(func(id): return Game.progress.is_unlocked(id)) and not Game.progress.schools_in_tier(4).any(func(id): return Game.progress.is_unlocked(id)), "T4: Tier 3 open, Tier 4 still locked")
	# a conference final not played yet (drawn, no result) earns nothing
	Game.progress = Progression.fresh()
	var c2 := Career.new_game("HURST", "A", "B", 5)
	var g := _force(c2, "conf_final", true)
	g.r = null
	c2.check_glory()
	r.check(Game.progress.done.is_empty(), "T4: being drawn into the final earns nothing until it's played")
	Game.career = null

# ------------------------------------------------------------------ T6
func _titles() -> void:
	# a full simulated season for a powerhouse: the title achievement iff the final was won
	var seen_champ := false
	var agree := true
	for seed in [21, 22, 23, 24]:
		Game.progress = Progression.fresh()
		var c := Career.new_game("CULA", "A", "B", seed)
		Game.career = c
		_sim_until(c, func(): return false)
		var champ := false
		for rd in c.schedule:
			if rd.kind == "nat_final":
				for g in rd.games:
					champ = g.r != null and Schedule.winner(g) == "CULA"
		seen_champ = seen_champ or champ
		agree = agree and (("nat_champ" in Game.progress.done) == champ)
		agree = agree and (Game.progress.schools_in_tier(5).all(func(id): return Game.progress.is_unlocked(id)) == champ)
	r.check(agree, "T6: in four simulated seasons the national title achievement matches the NCSA final won")
	# losing the final: no Tier 5
	Game.progress = Progression.fresh()
	var c2 := Career.new_game("FORDU", "A", "B", 7)
	_force(c2, "nat_final", false)
	c2.check_glory()
	r.check(not "nat_champ" in Game.progress.done and not Game.progress.schools_in_tier(5).any(func(id): return Game.progress.is_unlocked(id)), "T6: reaching the NCSA final and losing it opens no powerhouse")
	_force(c2, "nat_final", true)
	c2.check_glory()
	r.check("nat_champ" in Game.progress.done and Game.progress.schools_in_tier(5).all(func(id): return Game.progress.is_unlocked(id)), "T6: winning it opens the four highest-rated schools")
	r.check(_sorted(Game.progress.schools_in_tier(5)) == _sorted(["CULA", "CUSC", "STAM", "ALC"]), "T6: ...the Bears, Spartans, Redwoods and Golden Grizzlies")
	r.check(_queued(c2) == ["nat_champ"] and int(c2.queue.filter(func(q): return String(q.type) == "achievement")[0].count) == 4, "T6: NATIONAL CHAMPION, 4 new programs")
	Game.career = null

# ------------------------------------------------------------------ T7, T8 (+ T25: no bypass)
func _locked() -> void:
	Game.career = null
	Game.progress = Progression.fresh()
	Game.goto("new_career")
	for _i in 3:
		await r.get_tree().process_frame
	var scr = Game.current_screen
	var was: String = scr.pick
	scr.cards.CULA.pressed.emit()
	await r.get_tree().process_frame
	r.check(scr.pick == was, "T7: tapping a locked card picks nothing (pick still %s)" % scr.pick)
	r.check(scr.cards.CULA.modulate != Color.WHITE and scr.cards.CULA.find_child("Lock", true, false) != null and scr.cards[was].modulate == Color.WHITE, "T7: the locked card is faded, with its lock")
	r.check(not scr.next_button.disabled, "T7: NEXT still takes your open pick")
	scr.cards.CULA.pressed.emit()   # (tapped again)
	await r.get_tree().process_frame
	r.check(scr.step == 0 and scr.pick == was, "T7: tapping it again still picks nothing")
	# a locked school can't come through stale state either: NEXT and START check again
	scr.pick = "CULA"
	scr._render()
	await r.get_tree().process_frame
	r.check(scr.next_button.disabled, "T25: a stale locked pick: NEXT is off")
	scr._next()
	r.check(scr.step == 0, "T25: ...and does nothing")
	scr.step = 1
	scr._render()
	scr._start()
	await r.get_tree().process_frame
	r.check(Game.career == null and scr.step == 0, "T25: START CAREER refuses a locked school")
	r.check(not Game.start_career("CULA", "A", "B", 1) and Game.career == null, "T25: Game.start_career refuses it too")
	r.check(not Game.start_career("NOPE", "A", "B", 1), "T25: and an unknown id")
	# a refused start leaves the slot's save untouched
	_scratch()
	var saved_dir := Game.save_dir
	var saved_slot := Game.slot
	Game.save_dir = DIR
	Game.test_mode = false
	Game.progress = Progression.fresh()
	Game.career = Career.new_game("HURST", "Old", "Coach", 3)
	Game.slot = 1
	Game.save_career()
	var before := FileAccess.get_file_as_string(Game.slot_path(1))
	Game.career = null
	var refused := not Game.start_career("STAM", "New", "Coach", 4)
	r.check(refused and FileAccess.get_file_as_string(Game.slot_path(1)) == before, "T25: a refused start doesn't touch the slot's save")
	r.check(Game.start_career("WAGN", "New", "Coach", 4) and Game.career.school == "WAGN" and Game.load_career(1) and Game.career.school == "WAGN", "T7: an unlocked school starts (and saves)")
	Game.test_mode = true
	Game.save_dir = saved_dir
	Game.slot = saved_slot
	Game.career = null
	# an unlocked one goes on through NEXT
	Game.progress = Progression.fresh()
	Game.goto("new_career")
	for _i in 3:
		await r.get_tree().process_frame
	scr = Game.current_screen
	scr.cards.HURST.pressed.emit()
	await r.get_tree().process_frame
	r.check(scr.pick == "HURST", "T7: tapping an open card picks it")
	var nx: Button = scr.next_button
	r.check(nx != null and not nx.disabled, "T7: NEXT is live for it")
	if nx != null:
		nx.pressed.emit()
	await r.get_tree().process_frame
	r.check(scr.step == 1, "T7: and NEXT goes on to YOUR COACH")
	Game.goto("title")
	await r.get_tree().process_frame

func _persistence() -> void:
	_scratch()
	var saved_dir := Game.save_dir
	var saved_slot := Game.slot
	Game.save_dir = DIR
	Game.test_mode = false
	Game.progress = null
	var p := Game.progression()
	r.check(p.unlocked.size() == 5 and FileAccess.file_exists(Game.progress_path()), "T8: a new profile is made and saved")
	var got := p.award(["conf_champ"], "2026-27", "HURST")
	Game.save_progress()
	r.check(got.size() == 1 and int(got[0].count) == 7, "T8: winning a conference opens 7")
	Game.progress = null   # (closing the game)
	var q := Game.progression()
	r.check(q.done == ["conf_champ"] and q.unlocked.size() == 12 and q.schools_in_tier(4).all(func(id): return q.is_unlocked(id)), "T8: reopened, the achievement and its 7 schools are still there")
	r.check(not FileAccess.file_exists(Game.progress_path() + ".tmp"), "T8: saved by write-then-rename (no .tmp left)")
	var t4: String = q.schools_in_tier(4)[0]
	Game.slot = 3
	r.check(Game.start_career(t4, "A", "B", 9) and Game.career.school == t4, "T8: a new career can start at a Tier 4 school (%s)" % t4)
	Game.progress = null
	r.check(Game.progression().done == ["conf_champ"] and Game.progression().unlocked.size() == 12, "T8: a new career resets nothing")
	# a damaged profile is kept, and a new one rebuilt from the saved careers
	var f := FileAccess.open(Game.progress_path(), FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	Game.career.coach.titles = ["2026-27 Big West"]
	Game.save_career()
	Game.progress = null
	var re := Game.progression()
	r.check(FileAccess.file_exists(DIR + "progression_damaged.json") and "conf_champ" in re.done, "T8: a damaged profile is kept aside and rebuilt from the careers' records")
	Game.test_mode = true
	Game.save_dir = saved_dir
	Game.slot = saved_slot
	Game.career = null
	Game.progress = Progression.fresh()
	_scratch()

# ------------------------------------------------------------------ T9 (+ T27: old saves)
func _existing_save() -> void:
	_scratch()
	var saved_dir := Game.save_dir
	var saved_slot := Game.slot
	Game.save_dir = DIR
	Game.test_mode = false
	# a career at a powerhouse from before the Road to Glory
	var c := Career.new_game("CULA", "Old", "Save", 17)
	c.queue.clear()
	for _i in 2:
		if c.has_game():
			c.sim_my_game()
		c.end_week()
	var roster: Array = c.team().roster.map(func(pl): return pl.id)
	var wk := c.week
	Game.career = c
	Game.slot = 2
	Game.save_career()
	var text := FileAccess.get_file_as_string(Game.slot_path(2))
	Game.career = null
	if FileAccess.file_exists(Game.progress_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.progress_path()))
	Game.progress = null
	var p := Game.progression()   # (first run: the profile is made from the saves)
	r.check(not p.is_unlocked("CULA"), "T9: the Bears are locked on the new profile")
	r.check(FileAccess.get_file_as_string(Game.slot_path(2)) == text, "T9: making the profile doesn't touch the save")
	r.check(Game.load_career(2) and Game.career.school == "CULA" and Game.career.week == wk, "T9: the CULA dynasty still loads, same week")
	r.check(Game.career.team().roster.map(func(pl): return pl.id) == roster, "T9: same roster")
	var played := 0
	while Game.career.has_game() and played < 1:
		Game.career.sim_my_game()
		played += 1
	r.check(played == 1, "T9: and plays on")
	# what an old save's records prove is counted, nothing more
	var old := Career.new_game("FORDU", "Old", "Champ", 5)
	old.history = [{"year": "2026-27", "team": "FORDU", "w": 11, "l": 5}]
	old.coach.titles = ["2026-27 MAWPC"]
	Game.career = old
	Game.slot = 4
	Game.save_career()
	Game.career = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.progress_path()))
	Game.progress = null
	var p2 := Game.progression()
	r.check(_sorted(p2.done) == _sorted(["five_wins", "conf_final", "conf_champ"]), "T27: an old 11-5 conference-champion save proves Tiers 2-4, not the national title %s" % str(p2.done))
	r.check(p2.unlocked.size() == 26 and not p2.schools_in_tier(5).any(func(id): return p2.is_unlocked(id)), "T27: 26 schools open, the top four still locked")
	var p3 := Progression.fresh()
	p3.reconstruct(["2027-28 NCSA"], [])
	r.check(p3.done == ["nat_champ"], "T27: an NCSA title in the coach's record proves the title alone")
	Game.test_mode = true
	Game.save_dir = saved_dir
	Game.slot = saved_slot
	Game.career = null
	Game.progress = Progression.fresh()
	_scratch()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))

# ------------------------------------------------------------------ T10 (geometry; sizes need a window)
func _layout() -> void:
	# 16:9, the wide iPhones (19.5:9), an older 2:1 phone and 4:3; headless: one pass as it is
	var sizes: Array = [Vector2i(1440, 810), Vector2i(1752, 810), Vector2i(1620, 810), Vector2i(1080, 810)] if DisplayServer.get_name() != "headless" else [Vector2i.ZERO]
	for sz in sizes:
		if sz != Vector2i.ZERO:
			DisplayServer.window_set_size(sz)
			await r.get_tree().create_timer(0.3).timeout
		Game.progress = Progression.fresh()
		Game.progress.award(["five_wins"])
		Game.goto("new_career")
		for _i in 4:
			await r.get_tree().process_frame
		var scr = Game.current_screen
		var view: Rect2 = scr.get_viewport_rect()
		var tag := "%dx%d" % [int(view.size.x), int(view.size.y)]
		var sc: ScrollContainer = scr.list_scroll
		var wide: bool = scr.list.size.x <= sc.size.x + 0.5 and sc.size.x >= view.size.x - 24
		var cards_ok := true
		var rects: Array = []
		for id in scr.cards:
			var cd: Control = scr.cards[id]
			cards_ok = cards_ok and cd.size.y == scr.CARD_H and cd.size.x >= scr.CARD_MIN_W and cd.get_global_rect().end.x <= sc.get_global_rect().end.x + 0.5
			rects.append(cd.get_global_rect())
		for a in rects.size():
			for b in range(a + 1, rects.size()):
				cards_ok = cards_ok and not (rects[a] as Rect2).grow(-0.5).intersects(rects[b])
		var logos := true
		for id in scr.cards:
			var lg: Control = scr.cards[id].find_child("Logo", true, false)
			logos = logos and lg != null and lg.size.x <= scr.LOGO_FIT.x and lg.size.y <= scr.LOGO_FIT.y and (not lg is TextureRect or lg.size == Vector2(lg.texture.get_size()))
		var nb: Button = scr.next_button
		var nb_in := nb != null and Rect2(Vector2.ZERO, view.size).grow(0.5).encloses(nb.get_global_rect()) and not nb.get_global_rect().intersects(sc.get_global_rect())
		r.check(wide and cards_ok, "T10 %s: %d cards a row across the page, all %d px tall, never overlapping or past the edge" % [tag, scr.columns(), scr.CARD_H])
		r.check(scr.columns() >= 4, "T10 %s: at least four to a row (%d)" % [tag, scr.columns()])
		r.check(nb_in, "T10 %s: NEXT on screen, clear of the cards" % tag)
		r.check(logos, "T10 %s: logos unstretched (their own files, 1:1)" % tag)
		r.check(_visible_cards(scr) >= scr.columns(), "T10 %s: a full row of cards in view at once (%d)" % [tag, _visible_cards(scr)])
	if sizes[0] != Vector2i.ZERO:
		DisplayServer.window_set_size(Vector2i(1440, 810))
	Game.goto("title")
	await r.get_tree().process_frame

func _visible_cards(scr) -> int:
	return scr.cards.keys().filter(func(id): return _in_view(scr, id)).size()

func _in_view(scr, id: String) -> bool:
	return scr.list_scroll.get_global_rect().grow(0.5).encloses(scr.cards[id].get_global_rect())

# ------------------------------------------------------------------ T11
func _nonsequential() -> void:
	var p := Progression.fresh()
	var got := p.award(["nat_champ"])
	r.check(got.size() == 1 and p.done == ["nat_champ"], "T11: a national title first earns only itself")
	r.check(p.schools_in_tier(5).all(func(id): return p.is_unlocked(id)) and p.unlocked.size() == 9, "T11: Tier 5 opens with Tier 1 (9 open)")
	for t in [2, 3, 4]:
		r.check(not p.schools_in_tier(t).any(func(id): return p.is_unlocked(id)), "T11: Tier %d still locked" % t)
	p.award(["conf_champ"])
	r.check(_sorted(p.done) == _sorted(["nat_champ", "conf_champ"]) and not "conf_final" in p.done and not "five_wins" in p.done, "T11: a conference title then adds Tier 4 alone")
	r.check(p.unlocked.size() == 16 and p.schools_in_tier(5).all(func(id): return p.is_unlocked(id)), "T11: no school relocked (16 open)")
	# a real conference title won earns Tier 3 too: the final was played
	var p2 := Progression.fresh()
	var c := Career.new_game("HURST", "A", "B", 5)
	_force(c, "conf_final", true)
	p2.note(c)
	r.check(_sorted(p2.done) == _sorted(["conf_final", "conf_champ"]) and not "five_wins" in p2.done, "T11: winning a conference final (1 win) gives Tiers 3 and 4, not the five-win one")
	var d := Progression.from_dict({"version": 1, "tiers": p.tiers, "done": p.done, "unlocked": p.unlocked})
	d.award(["five_wins"])
	r.check(p.unlocked.all(func(id): return d.is_unlocked(id)) and d.unlocked.size() == 23, "T11: earning another later keeps every unlock")

# ------------------------------------------------------------------ T12
func _duplicates() -> void:
	Game.progress = Progression.fresh()
	var c := Career.new_game("CULA", "A", "B", 41)
	Game.career = c
	c.queue.clear()
	# four wins simulated, then the fifth played on the match screen: its box handed in twice
	_sim_until(c, func(): return Progression.season_wins(c.school, c.schedule) >= 4)
	var guard := 0
	while not c.has_game() and guard < 5:
		guard += 1
		c.end_week()
	var box := {"uid": "glory-dup", "score": [12, 3], "won": true, "played": c.team().starters()}
	var w0 := Progression.season_wins(c.school, c.schedule)
	var credits := int(c.coach.wins)
	c.finish_my_game(box)
	c.finish_my_game(box)
	r.check(Progression.season_wins(c.school, c.schedule) == w0 + 1 and int(c.coach.wins) == int(credits) + 1, "T12: the same result handed in twice counts one win (%d -> %d)" % [w0, Progression.season_wins(c.school, c.schedule)])
	r.check(_queued(c).count("five_wins") == 1, "T12: one notification %s" % str(_queued(c)))
	c.check_glory()
	c.check_glory()
	Game.progress.note(c)
	r.check(_queued(c).count("five_wins") == 1 and Game.progress.done.count("five_wins") == 1 and Game.progress.earned.size() == 1, "T12: reading the results again adds nothing")
	r.check(Game.progress.unlocked.size() == 12 and Game.progress.award(["five_wins"]).is_empty(), "T12: progression stays consistent (12 open)")
	Game.career = null

# ------------------------------------------------------------------ T19: notifications
func _notifications() -> void:
	Game.progress = Progression.fresh()
	var c := Career.new_game("HURST", "A", "B", 5)
	c.queue.clear()
	c.hot_tip = true
	_force(c, "conf_final", true)
	c.check_glory()
	r.check(_queued(c) == ["conf_final", "conf_champ"], "T19: two at once are queued in order %s" % str(_queued(c)))
	Game.career = c
	Game.goto("hub")
	for _i in 4:
		await r.get_tree().process_frame
	var shown := _dialogs()
	r.check(shown.size() == 1 and "ACHIEVEMENT UNLOCKED!" in shown[0] and "CONFERENCE FINALIST" in shown[0] and "7 NEW PROGRAMS AVAILABLE!" in shown[0], "T19: the hub shows the first: ACHIEVEMENT UNLOCKED! CONFERENCE FINALIST, 7 NEW PROGRAMS AVAILABLE!")
	_press_ok()
	for _i in 3:
		await r.get_tree().process_frame
	shown = _dialogs()
	r.check(shown.size() == 1 and "CONFERENCE CHAMPION" in shown[0], "T19: then the second, never both at once")
	_press_ok()
	for _i in 3:
		await r.get_tree().process_frame
	r.check(_dialogs().is_empty() and _queued(c).is_empty(), "T19: then they're gone, and stay gone")
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _dialogs() -> Array:
	var out: Array = []
	for layer in Game.overlay.get_children():
		if layer is Control and not layer.is_queued_for_deletion():
			var texts: Array = layer.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
			if "ACHIEVEMENT UNLOCKED!" in texts:
				out.append(texts)
	return out

## OK on the notification showing (other tests' dialogs may still be in the overlay).
func _press_ok() -> void:
	for layer in Game.overlay.get_children():
		if layer is Control and not layer.is_queued_for_deletion() and layer.find_children("*", "Label", true, false).any(func(l): return (l as Label).text == "ACHIEVEMENT UNLOCKED!"):
			var b: Button = r._find_button(layer, "OK")
			if b != null:
				b.pressed.emit()
				return

# ------------------------------------------------------------------ T26-28: the saved profile
func _migration() -> void:
	var p := Progression.fresh()
	p.award(["five_wins"])
	var d: Dictionary = JSON.parse_string(JSON.stringify(p.to_dict()))
	r.check(int(d.version) == Progression.VERSION and d.has("tiers") and d.has("done") and d.has("unlocked") and d.has("best_wins") and d.has("season"), "T26: the profile saves its version, tiers, achievements, unlocks and progress")
	r.check((d.tiers as Dictionary).keys().all(func(id): return Colleges.school(String(id)).short == id), "T26: by stable school ids")
	# tiers are kept as saved, even if the ratings were to change
	d.tiers.HURST = 3
	d.unlocked.erase("HURST")
	var q := Progression.from_dict(d)
	r.check(q.tier_of("HURST") == 3 and not q.is_unlocked("HURST"), "T26: a saved tier is kept, not recomputed from today's ratings")
	# a school the profile doesn't know (added later) gets today's tier; nothing is relocked
	var e: Dictionary = JSON.parse_string(JSON.stringify(p.to_dict()))
	(e.tiers as Dictionary).erase("CULA")
	e.unlocked.append("NOT_A_SCHOOL")
	var q2 := Progression.from_dict(e)
	r.check(q2.tier_of("CULA") == 5 and q2.tiers.size() == 30 and not q2.is_unlocked("NOT_A_SCHOOL") and q2.unlocked.size() == 12, "T28: a missing school gets its tier; unknown ids are dropped; unlocks kept")
	var q3 := Progression.from_dict({"tiers": {}, "done": ["bogus"], "unlocked": "x"})
	r.check(q3.unlocked.size() == 5 and q3.done.is_empty(), "T28: a broken profile still loads as a new one")
	# no credits involved anywhere
	var src := FileAccess.get_file_as_string("res://src/core/progression.gd") + FileAccess.get_file_as_string("res://src/ui/screens/new_career.gd")
	# (the store ties are the ALL 30 TEAMS purchase: all_teams_test)
	var store_uses := RegEx.create_from_string("Store\\.(\\w+)").search_all(src).map(func(m): return m.get_string(1))
	r.check(not src.contains("spend_credits") and not src.contains("vault") and store_uses.all(func(u): return u in ["all_teams", "owns", "TEAMS_ID", "price", "state_changed"]), "T22: no credit or vault unlocks; the store only for ALL 30 TEAMS %s" % str(store_uses))

# ------------------------------------------------------------------ shots
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var plans := [["g01_new_player", [], "", Vector2i(1440, 810)], ["g02_locked_powerhouse", [], "CULA", Vector2i(1440, 810)],
		["g03_returning", ["five_wins", "conf_final"], "UPAC", Vector2i(1440, 810)], ["g04_iphone", ["five_wins"], "FORDU", Vector2i(1752, 810)],
		["g05_4x3", [], "LBSC", Vector2i(1080, 810)]]
	for pl in plans:
		DisplayServer.window_set_size(pl[3])
		await tree.create_timer(0.3).timeout
		Game.progress = Progression.fresh()
		Game.progress.award(pl[1])
		Game.progress.season = {"slot": 0, "year": "2026-27", "team": "HURST", "wins": 3}
		Game.career = null
		Game.goto("new_career")
		await tree.create_timer(0.5).timeout
		if String(pl[2]) != "":
			Game.current_screen._pick(String(pl[2]))
			await tree.create_timer(0.2).timeout
		if String(pl[0]) == "g02_locked_powerhouse":
			Game.current_screen.list_scroll.scroll_vertical = 150   # (down to the locked cards)
			await tree.create_timer(0.2).timeout
		await tree.process_frame
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(String(pl[0]) + ".png"))
		print("  shot ", pl[0])
	DisplayServer.window_set_size(Vector2i(1440, 810))
	await tree.create_timer(0.3).timeout
	var c := Career.new_game("HURST", "A", "B", 5)
	c.queue.clear()
	c.hot_tip = true
	Game.progress = Progression.fresh()
	var g := {"h": "HURST", "a": "IONA", "r": {"s": [9, 4], "so": [], "w": 0}}
	for rd in c.schedule:
		if rd.kind == "conf_final":
			rd.games = [g]
	c.check_glory()
	Game.career = c
	Game.goto("hub")
	await tree.create_timer(0.6).timeout
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("g06_notification.png"))
	print("  shot g06_notification")
	# the logos around the career: hub, standings, matchup, scouting
	for layer in Game.overlay.get_children():
		layer.queue_free()
	c = Career.new_game("SJCU", "A", "B", 5)
	c.queue.clear()
	c.hot_tip = true
	Game.career = c
	for scr in ["hub", "conference", "matchup", "scout"]:
		Game.goto(scr)
		await tree.create_timer(0.6).timeout
		runner.get_viewport().get_texture().get_image().save_png(out.path_join("g07_%s.png" % scr))
		print("  shot g07_", scr)
	Game.career = null
	Game.progress = null
