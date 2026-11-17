extends RefCounted
## AUTOMATIC WALK-ON RECRUITMENT & ROSTER COMPLETION (WalkOns, Offseason.finish, WalkOnShow):
##   godot --headless --path game -- --test walk_ons
##   godot --path game --resolution 960x540 -- --test walk_ons_png <dir>   (frames: needs a window)

var r

func _frames(n: int) -> void:
	for _i in n:
		await r.get_tree().process_frame

func run(runner) -> void:
	r = runner
	print("walk_ons")
	_odds()
	_making()
	_plans()
	_no_potential()
	_season()
	await _screens()
	await _lab()

# ------------------------------------------------------------------ the dice
func _odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 40000
	var got := {}
	var top := 0.0
	for _i in n:
		var s := WalkOns.roll_stars(rng)
		got[s] = int(got.get(s, 0)) + 1
		top = maxf(top, s)
	for e in WalkOns.STAR_ODDS:
		var share := float(got.get(float(e[0]), 0)) / n
		r.check(absf(share - float(e[1]) / 100.0) < 0.01, "O1: %s stars come up %d%% of the time (%.1f%%)" % [str(e[0]), int(e[1]), share * 100.0])
	var low := float(int(got.get(0.5, 0)) + int(got.get(1.0, 0)) + int(got.get(1.5, 0))) / n
	r.check(absf(low - 0.9) < 0.01, "O2: 90%% are 0.5-1.5 stars (%.1f%%)" % (low * 100.0))
	r.check(top <= WalkOns.MAX_STARS, "O3: never above 2.5 stars")
	var sum := 0
	for e in WalkOns.STAR_ODDS:
		sum += int(e[1])
	r.check(sum == 100, "O4: the odds add up to 100")

# ------------------------------------------------------------------ one walk-on
func _making() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var exact := true
	var flat := true
	var keeper_keys := true
	var field_keys := true
	var years := {}
	var shapes := {}
	var looks := true
	var n := 0
	for stars in [0.5, 1.0, 1.5, 2.0, 2.5]:
		for pos in [PoloPlayer.Pos.GK, PoloPlayer.Pos.CENTER, PoloPlayer.Pos.DRIVER, PoloPlayer.Pos.WING, PoloPlayer.Pos.DEFENDER, PoloPlayer.Pos.UTILITY]:
			for _i in 40:
				var p := WalkOns.make(rng, pos, stars, {})
				n += 1
				exact = exact and is_equal_approx(p.stars, stars) and is_equal_approx(Attributes.stars_of(Attributes.overall(p)), stars)
				flat = flat and is_equal_approx(p.pot_stars, p.stars) and p.attrs == p.attr_pot and Development.boxes_left(p) == 0
				if p.is_keeper():
					keeper_keys = keeper_keys and p.attrs.keys().all(func(k): return k in Attributes.KEEPER) and p.attrs.size() == 4
				else:
					field_keys = field_keys and p.attrs.keys().all(func(k): return k in Attributes.FIELD) and p.attrs.size() == 4
				years[p.year] = int(years.get(p.year, 0)) + 1
				shapes[str(p.attrs)] = true
				looks = looks and p.first != "" and p.last != "" and p.home != "" and p.region != "" and p.walk_on and p.walkon_rookie and not p.schol
	r.check(exact, "M1: every walk-on rates exactly the stars he was drawn at (the game's own calculation)")
	r.check(flat, "M2: every ceiling is his attribute: POTENTIAL = CURRENT, no boxes left")
	r.check(keeper_keys, "M3: a keeper walk-on has the four keeper attributes")
	r.check(field_keys, "M4: a field walk-on has the four field attributes")
	r.check(shapes.size() > n / 4, "M5: walk-ons aren't made alike (%d shapes in %d)" % [shapes.size(), n])
	r.check(looks, "M6: a name, hometown and region; WALK-ON; no scholarship")
	var yr_ok := true
	for y in [1, 2, 3, 4]:
		var share := float(years.get(y, 0)) / n
		yr_ok = yr_ok and absf(share - 0.25) < 0.04
	r.check(yr_ok and years.size() == 4, "M7: FR / SO / JR / SR a quarter each (%s)" % str(years))
	# the attributes vary within a rating: a 1.5-star walk-on's four aren't all the same
	var spread := 0
	for _i in 50:
		var p := WalkOns.make(rng, PoloPlayer.Pos.WING, 1.5, {})
		var vals: Array = p.attrs.values()
		if vals.max() - vals.min() >= 2.0:
			spread += 1
	r.check(spread >= 20, "M8: his four attributes vary (%d of 50 spread 2+ points)" % spread)

# ------------------------------------------------------------------ the positions
func _team(n_gk: int, n_field: int) -> PoloTeam:
	var t := PoloTeam.new()
	t.id = "TEST"
	var rng := RandomNumberGenerator.new()
	rng.seed = n_gk * 31 + n_field
	for i in n_gk:
		var p := WalkOns.make(rng, PoloPlayer.Pos.GK, 1.0, {})
		p.id = 1000 + i
		t.roster.append(p)
	for i in n_field:
		var p := WalkOns.make(rng, CollegeGen.ROSTER_POS[1 + i % 6], 1.0, {})
		p.id = 2000 + i
		t.roster.append(p)
	return t

func _plans() -> void:
	var c := Career.new()
	var cap := c.roster_cap("TEST")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var gk_count := func(a: Array) -> int: return a.filter(func(x): return int(x) == PoloPlayer.Pos.GK).size()
	# A: one keeper, short four: a keeper, then field players
	var a := WalkOns.plan(c, _team(1, cap - 5), rng)
	r.check(a.size() == 4 and gk_count.call(a) == 1, "P1: one keeper, four places: 1 keeper + 3 field (%s)" % str(a))
	# B: two keepers: field players only
	var b := WalkOns.plan(c, _team(2, cap - 8), rng)
	r.check(b.size() == 6 and gk_count.call(b) == 0, "P2: two keepers, six places: 6 field (%s)" % str(b))
	# C: one place, no keeper: the keeper
	var cc := WalkOns.plan(c, _team(0, cap - 1), rng)
	r.check(cc.size() == 1 and gk_count.call(cc) == 1, "P3: one place and no keeper: a keeper")
	# full: nothing
	r.check(WalkOns.plan(c, _team(2, cap - 2), rng).is_empty(), "P4: a full roster gets nobody")
	# empty: two keepers at most (the keeper cap), the rest field, exactly the cap
	var e := WalkOns.plan(c, _team(0, 0), rng)
	r.check(e.size() == cap and gk_count.call(e) == mini(WalkOns.KEEPER_TARGET, c.keeper_cap("TEST")), "P5: an empty roster: %d, 2 keepers (%s)" % [cap, str(e)])
	# never more keepers than the cap, never a keeper when there are two
	r.check(gk_count.call(WalkOns.plan(c, _team(2, 1), rng)) == 0, "P6: two keepers already: no more keepers")
	r.check(e.all(func(x): return int(x) in [PoloPlayer.Pos.GK, PoloPlayer.Pos.CENTER, PoloPlayer.Pos.DEFENDER, PoloPlayer.Pos.DRIVER, PoloPlayer.Pos.WING, PoloPlayer.Pos.UTILITY]), "P7: only positions the game has")
	# the field players a lineup needs come before a second keeper
	var f := WalkOns.plan(c, _team(1, 3), rng)
	r.check(f.slice(0, 3).all(func(x): return int(x) != PoloPlayer.Pos.GK), "P8: six field players before the backup keeper (%s)" % str(f))

# ------------------------------------------------------------------ no potential
func _no_potential() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var p := WalkOns.make(rng, PoloPlayer.Pos.DRIVER, 1.5, {})
	p.id = 77
	Development.ensure(p)
	var before := p.attrs.duplicate()
	var tk := Development.award_xp(p, 100000)
	r.check(tk == 0 and p.tokens == 0, "Z1: XP earns no upgrade tokens (%d)" % tk)
	p.tokens = 3   # (as if something had handed him some)
	for k in p.key_ratings():
		r.check(not Development.can_spend(p, k) and not Development.spend(p, k), "Z2: no token buys a point of %s" % k)
	Attributes.add_points(p, p.key_ratings(), 6.0)
	Attributes.train(p, "shoot", 20.0)
	for k in p.key_ratings():
		Attributes.set_ceiling(p, k, 10.0)
		Attributes.set_value(p, k, 10.0)
	Attributes.refit_potential(p, 9.0)
	r.check(p.attrs == before and p.attr_pot == before and is_equal_approx(p.pot_stars, p.stars), "Z3: training, ceilings and refits can't move him")
	# HOT form plays on top and never stays
	p.heat = 2
	var hot := p.live("shoot")
	p.heat = 0
	r.check(hot > float(p.shoot) and p.attrs == before, "Z4: HOT form plays (%.0f > %d) and changes nothing permanent" % [hot, p.shoot])
	# a save keeps all of it
	var back := PoloPlayer.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	r.check(back.walk_on and back.walkon_rookie and back.attrs == before and back.attr_pot == before and back.id == 77 and back.year == p.year, "Z5: a save round-trip keeps him a walk-on, his attributes and ceilings")
	# a regular player: untouched by any of it
	var reg := CollegeGen.make_prospect(rng, 3.0, "high", {})
	r.check(not reg.walk_on and Development.boxes_left(reg) > 0, "Z6: a recruit keeps his room to grow")
	r.check(not reg.to_dict().has("walk_on"), "Z7: a regular player's save is as before")

# ------------------------------------------------------------------ the season transition
func _season() -> void:
	var c := Career.new_game("BUCK", "A", "B", 41)
	var me := c.team()
	# a small class: four of yours gone (never a keeper), and some AI programs short too
	var gone := me.roster.filter(func(p: PoloPlayer): return not p.is_keeper() and p.year < 4).slice(0, 4)
	for p in gone:
		me.roster.erase(p)
	var short_ai := 0
	for id in c.teams:
		if id == c.school or short_ai >= 5:
			continue
		var t: PoloTeam = c.teams[id]
		var gk: Array = t.roster.filter(func(p: PoloPlayer): return p.is_keeper())
		for p in gk:
			t.roster.erase(p)   # (no keeper at all: the walk-ons must bring one)
		short_ai += 1
	var ids_before := me.roster.filter(func(p: PoloPlayer): return p.year < 4).map(func(p: PoloPlayer): return p.id)
	var queue_before := c.queue.size()
	c.phase = "done"
	Offseason.transition(c)
	r.check(c.phase == "season", "S1: the next season started (%s)" % c.phase)
	r.check(me.roster.size() == c.roster_cap(c.school), "S2: your roster is full: %d / %d" % [me.roster.size(), c.roster_cap(c.school)])
	var walk: Array = me.roster.filter(func(p: PoloPlayer): return p.walk_on)
	var items: Array = c.queue.slice(queue_before).filter(func(q): return String(q.get("type", "")) == "walkons")
	r.check(items.size() == 1, "S3: one WELCOMING ALL WALK-ONS! announcement (%d)" % items.size())
	if items.size() == 1:
		r.check(int(items[0].n) == walk.size() and (items[0].ids as Array).size() == walk.size(), "S4: it counts the %d who joined" % walk.size())
		var at := c.queue.find(items[0])
		r.check(at > 0 and String(c.queue[at - 1].get("type", "")) == "recap", "S5: it comes straight after the roster set report")
	r.check(ids_before.all(func(pid): return me.find_id(int(pid)) != null), "S6: nobody of yours (but the graduates) left: walk-ons only add")
	r.check(walk.all(func(p: PoloPlayer): return p.stars <= WalkOns.MAX_STARS and p.attrs == p.attr_pot and not p.schol and p.walkon_rookie), "S7: your walk-ons: 2.5 stars at most, no potential, no scholarship")
	var nums := {}
	var unique := true
	for p: PoloPlayer in me.roster:
		unique = unique and not nums.has(p.number)
		nums[p.number] = true
	r.check(unique, "S8: every cap number different")
	var all_ids := {}
	var dup := false
	var legal := true
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		var gks := t.roster.filter(func(p: PoloPlayer): return p.is_keeper()).size()
		legal = legal and t.roster.size() == c.roster_cap(id) and gks >= 1 and gks <= c.keeper_cap(id) and t.roster.size() - gks >= Career.FIELD_MAX
		for p: PoloPlayer in t.roster:
			dup = dup or all_ids.has(p.id)
			all_ids[p.id] = true
	r.check(legal, "S9: every program full, a keeper at least, no more than its keeper cap")
	r.check(not dup, "S10: no player on two rosters, no id twice")
	# (the AI programs' own recruiting fills their places first, as it always has, so walk-ons only
	# take what it leaves: here, an AI program left short after it, as _ai_rosters' fill sees it)
	var ai_ok := true
	var ai_full := true
	var ai_walk := 0
	for id in c.teams.keys().slice(0, 6):
		if id == c.school:
			continue
		var t: PoloTeam = c.teams[id]
		var drop: Array = t.roster.filter(func(p: PoloPlayer): return p.is_keeper())
		drop.append_array(t.roster.filter(func(p: PoloPlayer): return not p.is_keeper()).slice(0, 3))
		for p in drop:
			t.roster.erase(p)
		var got := WalkOns.fill(c, t)
		ai_walk += got.size()
		ai_full = ai_full and t.roster.size() == c.roster_cap(id) and t.roster.any(func(p: PoloPlayer): return p.is_keeper())
		ai_ok = ai_ok and got.all(func(p: PoloPlayer): return p.walk_on and p.stars <= WalkOns.MAX_STARS and p.attrs == p.attr_pot)
	r.check(ai_walk > 0 and ai_ok and ai_full, "S11: AI programs left short get walk-ons by the same rules, full again (%d)" % ai_walk)
	# the rookie awards: any walk-on in his first season, whatever his year
	var upper: PoloPlayer = null
	for p in walk:
		if p.year > 1:
			upper = p
	if upper == null and not walk.is_empty():
		upper = walk[0]
		upper.year = 3
	if upper != null:
		r.check(ConfAwards.eligible(upper, {}, "rotw") and WalkOns.is_rookie(upper), "S12: a %s walk-on can be ROOKIE OF THE WEEK" % upper.year_text())
	# a save and a reload: nobody new, nothing lost, the announcement still waiting (once)
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var bme := back.team()
	r.check(bme.roster.size() == me.roster.size() and bme.roster.map(func(p: PoloPlayer): return p.id) == me.roster.map(func(p: PoloPlayer): return p.id), "S13: a reload brings back the same roster")
	r.check(bme.roster.filter(func(p: PoloPlayer): return p.walk_on).size() == walk.size(), "S14: ...the same walk-ons")
	r.check(back.queue.filter(func(q): return String(q.get("type", "")) == "walkons").size() == 1, "S15: ...and the announcement once")
	# a roster already full: nobody new, no announcement
	r.check(WalkOns.fill(c, me).is_empty(), "S16: filling a full roster adds nobody")
	var q2 := c.queue.size()
	c.phase = "done"
	c.incoming = []
	Offseason.finish(c)   # (the roster set again, full: as a season with no gaps)
	r.check(c.queue.slice(q2).filter(func(q): return String(q.get("type", "")) == "walkons").is_empty(), "S17: a full roster: no announcement")
	r.check(me.roster.size() == c.roster_cap(c.school), "S18: and it's still exactly full")
	# the next season: his rookie year is over, he's still a walk-on, still without potential
	c.phase = "done"
	Offseason.transition(c)
	var still: Array = walk.filter(func(p: PoloPlayer): return me.find_id(p.id) != null)
	r.check(still.all(func(p: PoloPlayer): return p.walk_on and not p.walkon_rookie and p.attrs == p.attr_pot), "S19: a year on: still a walk-on, no potential, not a rookie any more")
	r.check(still.all(func(p: PoloPlayer): return p.year <= 4), "S20: walk-ons graduate like anyone (no fifth year)")

# ------------------------------------------------------------------ the screens
func _screens() -> void:
	var c := Career.new_game("BUCK", "A", "B", 42)
	var me := c.team()
	for p in me.roster.filter(func(p: PoloPlayer): return not p.is_keeper() and p.year < 4).slice(0, 3):
		me.roster.erase(p)
	c.phase = "done"
	Offseason.transition(c)
	var item: Dictionary = {}
	for q in c.queue:
		if String(q.get("type", "")) == "walkons":
			item = q
	r.check(not item.is_empty(), "U0: an announcement queued")
	if item.is_empty():
		return
	# the show on its own
	var closed := [0]
	var s := WalkOnShow.play(Game.overlay, c, item, func(): closed[0] += 1, false)
	await _frames(2)
	r.check(s.players.size() == int(item.n), "U1: it shows every walk-on (%d)" % s.players.size())
	r.check(s.blurb.text == WalkOnShow.BLURB and s.count_l.text == WalkOnShow.count_text(int(item.n)), "U2: the message and the count (%s)" % s.count_l.text)
	r.check(s.view.text == "VIEW NEW WALK-ONS", "U3: VIEW NEW WALK-ONS")
	r.check(WalkOnShow.count_text(1) == "1 WALK-ON PLAYER HAS JOINED YOUR ROSTER!" and WalkOnShow.count_text(6) == "6 WALK-ON PLAYERS HAVE JOINED YOUR ROSTER!", "U4: one and many read right")
	s.view.pressed.emit()
	s.view.pressed.emit()
	await _frames(1)
	r.check(closed[0] == 1 and (not is_instance_valid(s) or s.is_queued_for_deletion()), "U5: closes once (%d)" % closed[0])
	# the hub: the queue to the show, VIEW NEW WALK-ONS to the roster with them lit up
	Game.career = c
	for q in c.upgrades_due():
		Development.ai_spend(q)
	while not c.queue.is_empty() and c.queue[0] != item:
		c.queue.pop_front()
	Game.goto("hub")
	await _frames(4)
	var show: WalkOnShow = Game.overlay.find_child("WalkOnShow", true, false)
	r.check(show != null, "U6: the hub shows it")
	if show != null:
		show.view.pressed.emit()
		await _frames(4)
		r.check(Game.current_name == "roster", "U7: VIEW NEW WALK-ONS opens the roster (%s)" % Game.current_name)
		var scr = Game.current_screen
		r.check(scr.walkon_ids.size() == int(item.n) and scr.walkon_ids.all(func(pid): return scr.lit_walkon(me.find_id(int(pid)))), "U8: with the walk-ons lit up")
		r.check(scr.find_child("WalkOnNote", true, false) != null, "U9: and a line saying so")
		r.check(not c.queue.has(item), "U10: the announcement is gone from the queue (never again)")
	# his page: WALK-ON
	var w: PoloPlayer = me.roster.filter(func(p: PoloPlayer): return p.walk_on)[0]
	Game.goto("player", {"id": w.id})
	await _frames(3)
	r.check(Game.current_screen.find_child("WalkOnLabel", true, false) != null, "U11: his page says WALK-ON")
	var reg: PoloPlayer = me.roster.filter(func(p: PoloPlayer): return not p.walk_on)[0]
	Game.goto("player", {"id": reg.id})
	await _frames(3)
	r.check(Game.current_screen.find_child("WalkOnLabel", true, false) == null, "U12: a recruited player's doesn't")
	Game.career = null

# ------------------------------------------------------------------ Developer Tools: WALK-ON TESTING
func _lab() -> void:
	var was: bool = bool(Game.settings.get("dev_mode", false))
	Game.settings["dev_mode"] = true
	Game.career = null
	Game.goto("walkon_lab")
	await _frames(3)
	var lab = Game.current_screen
	r.check(Game.current_name == "walkon_lab", "L1: WALK-ON TESTING opens (%s)" % Game.current_name)
	var ex: Array = lab.examples
	r.check(ex.size() == 6, "L2: six examples")
	r.check(ex.slice(0, 5).map(func(p): return (p as PoloPlayer).stars) == lab.EX_STARS and (ex[5] as PoloPlayer).is_keeper(), "L3: one at each rating, and a keeper")
	r.check(ex.all(func(p: PoloPlayer): return p.walk_on and p.attrs == p.attr_pot), "L4: real walk-ons: no potential")
	r.check(lab.find_child("Examples", true, false).get_child_count() == 6 and lab.find_child("Odds", true, false) != null, "L5: the examples and the odds on screen")
	var n := 0
	for k in lab.odds:
		n += int(lab.odds[k])
	r.check(n == lab.ROLLS and lab.odds.keys().all(func(k): return float(k) <= WalkOns.MAX_STARS), "L6: %d rolls, none above 2.5" % n)
	var first: PoloPlayer = ex[0]
	lab.find_child("RerollWalkOns", true, false).pressed.emit()
	await _frames(2)
	r.check(lab.examples[0] != first, "L7: REROLL makes a new set")
	for _i in 3:
		lab.find_child("SizeUp", true, false).pressed.emit()
	r.check(lab.size_n == 7 and lab.size_l.text == "CLASS SIZE: 7", "L8: CLASS SIZE + (%d)" % lab.size_n)
	for _i in 20:
		lab.find_child("SizeUp", true, false).pressed.emit()
	r.check(lab.size_n == Career.ROSTER_MAX + Career.BENCH_MAX, "L9: never past the roster's places")
	for _i in 20:
		lab.find_child("SizeDown", true, false).pressed.emit()
	r.check(lab.size_n == 1, "L10: never below one")
	lab.size_n = 6
	lab.find_child("PreviewWalkOnPopup", true, false).pressed.emit()
	await _frames(2)
	var show: WalkOnShow = Game.overlay.find_child("WalkOnShow", true, false)
	r.check(show != null and show.preview and show.players.size() == 6 and show.count_l.text == WalkOnShow.count_text(6), "L11: PREVIEW POPUP shows a class of six")
	if show != null:
		show.view.pressed.emit()
		await _frames(2)
		r.check(not is_instance_valid(show) or show.is_queued_for_deletion(), "L12: VIEW NEW WALK-ONS closes the preview")
		r.check(Game.current_name == "walkon_lab" and Game.career == null, "L13: and nothing else happens: no career, still in the lab")
	Game.settings["dev_mode"] = was

## The show's frames, the roster with them lit, a walk-on's page.
static func shots(runner, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var c := Career.new_game("BUCK", "A", "B", 42)
	var me := c.team()
	for p in me.roster.filter(func(p: PoloPlayer): return not p.is_keeper() and p.year < 4).slice(0, 3):
		me.roster.erase(p)
	c.phase = "done"
	Offseason.transition(c)
	c.sandbox = true
	Game.career = c
	for q in c.upgrades_due():
		Development.ai_spend(q)
	var item: Dictionary = {}
	for q in c.queue:
		if String(q.get("type", "")) == "walkons":
			item = q
	c.queue = []
	Game.goto("hub")
	for _i in 4:
		await runner.get_tree().process_frame
	var s := WalkOnShow.play(Game.overlay, c, item, Callable(), true)
	for tt in [0.2, 0.5, 0.9, 3.0]:
		s.t = tt
		s._apply()
		s.queue_redraw()
		await runner.get_tree().process_frame
		await runner.get_tree().process_frame
		runner.get_viewport().get_texture().get_image().save_png("%s/walkons_%.1f.png" % [dir, tt])
	s.queue_free()
	Game.goto("roster", {"walkons": item.get("ids", [])})
	for _i in 6:
		await runner.get_tree().process_frame
	runner.get_viewport().get_texture().get_image().save_png(dir + "/walkons_roster.png")
	var w: PoloPlayer = me.roster.filter(func(p: PoloPlayer): return p.walk_on)[0]
	Game.goto("player", {"id": w.id})
	for _i in 6:
		await runner.get_tree().process_frame
	runner.get_viewport().get_texture().get_image().save_png(dir + "/walkons_player.png")
	# Developer Tools' WALK-ON TESTING, and its popup preview
	Game.settings["dev_mode"] = true
	Game.goto("walkon_lab")
	for _i in 6:
		await runner.get_tree().process_frame
	runner.get_viewport().get_texture().get_image().save_png(dir + "/walkons_lab.png")
	var lab = Game.current_screen
	lab.size_n = 10
	lab._preview()
	var ps: WalkOnShow = Game.overlay.find_child("WalkOnShow", true, false)
	ps.t = 3.0
	for _i in 3:
		await runner.get_tree().process_frame
	runner.get_viewport().get_texture().get_image().save_png(dir + "/walkons_lab_popup10.png")
	ps.queue_free()
	Game.career = null
	print("shots in ", dir)
