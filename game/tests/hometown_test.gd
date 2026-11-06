extends RefCounted
## The Hometown & Appearance update: hometowns (Hometowns: 70/30, California first, the water polo
## nations abroad, a starting roster's local lean), the new skin-shade weights (PoloPlayer
## SKIN_WEIGHTS: 40/30/20/8/2, drawn on their own), old saves' hometowns, and the profile's line.
##   godot --headless --path game -- --test hometowns
## Fixed seeds; the big samples are 10,000.

var r
const N := 10000

func run(runner) -> void:
	r = runner
	print("hometowns: skin tones")
	_skins()
	print("hometowns: the pool")
	_pool()
	print("hometowns: starting rosters and recruits")
	_rosters()
	print("hometowns: saves and screens")
	await _saves(runner)

# ------------------------------------------------------------------ skin
func _skins() -> void:
	r.check(PoloPlayer.SKIN == ["f1c9a5", "e0ac85", "c68a5e", "a86b43", "7d4a2b", "5a3520"], "6: the palette as it was, every shade kept")
	var total := 0.0
	for w in PoloPlayer.SKIN_WEIGHTS:
		total += w
	r.check(is_equal_approx(total, 100.0), "6: the weights add up to 100")
	# 10,000 players from the game's own generator (League._make_player: every college player,
	# recruit and club player is made there)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var shade := [0, 0, 0, 0, 0, 0]
	for i in N:
		var p := League._make_player(PoloPlayer.Pos.DRIVER, 60.0, rng, {})
		shade[p.skin] += 1
	var groups := {}
	for i in shade.size():
		var g: String = PoloPlayer.SKIN_GROUPS[i]
		groups[g] = int(groups.get(g, 0)) + int(shade[i])
	print("    10,000 players: %s (shades %s)" % [str(groups), str(shade)])
	var want := {"light": 4000, "medium-light": 3000, "medium": 2000, "dark": 800, "very dark": 200}
	var close := true
	for g in want:
		close = close and absf(float(groups.get(g, 0)) - float(want[g])) <= maxf(60.0, float(want[g]) * 0.06)
	r.check(close, "15: 10,000 generated players near 4,000 / 3,000 / 2,000 / 800 / 200")
	r.check(shade.all(func(n): return n > 0), "6/15: every shade still comes up (very dark %d: uncommon, not gone)" % shade[5])
	r.check(absf(shade[2] - shade[3]) < 200, "7: medium's two shades share its 20%% (%d / %d), the category no heavier" % [shade[2], shade[3]])
	# drawn on its own: the same shades for players from anywhere
	var by_home := {"us": [0, 0], "intl": [0, 0]}
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 99
	for i in 6000:
		var p := CollegeGen.make_prospect(rng2, 3.0, "average", {})
		var k := "us" if Hometowns.is_us(p.home) else "intl"
		by_home[k][0] += 1
		by_home[k][1] += 1 if p.skin >= 4 else 0
	var us_dark := float(by_home.us[1]) / maxf(1.0, by_home.us[0])
	var intl_dark := float(by_home.intl[1]) / maxf(1.0, by_home.intl[0])
	r.check(absf(us_dark - intl_dark) < 0.03, "8: skin doesn't follow hometown: dark or very dark %.1f%% of Americans, %.1f%% of internationals" % [us_dark * 100.0, intl_dark * 100.0])
	var src := FileAccess.get_file_as_string("res://src/core/polo_player.gd")
	r.check(src.contains("static func random_skin(rng: RandomNumberGenerator) -> int:"), "8: the skin draw takes nothing but the dice (no hometown, name or team)")

# ------------------------------------------------------------------ the pool
func _pool() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var us := 0
	var states := {}
	var countries := {}
	var valid := true
	for i in N:
		var h := Hometowns.pick(rng)
		valid = valid and _valid(h)
		var place := Hometowns.place_of(h)
		if Hometowns.is_us(h):
			us += 1
			states[place] = int(states.get(place, 0)) + 1
		else:
			countries[place] = int(countries.get(place, 0)) + 1
	var top := ""
	for s in states:
		if top == "" or int(states[s]) > int(states[top]):
			top = s
	var ca := float(states.get("California", 0)) / us
	print("    10,000 hometowns: %d American (California %.1f%%, Texas %.1f%%), %d abroad from %d countries %s" % [us, ca * 100.0,
		100.0 * states.get("Texas", 0) / us, N - us, countries.size(), str(countries)])
	r.check(absf(float(us) / N - 0.70) < 0.02, "2: about 70%% American, 30%% international (%.1f%% / %.1f%%)" % [100.0 * us / N, 100.0 - 100.0 * us / N])
	r.check(top == "California" and absf(ca - 0.45) < 0.03, "3: California the most common state (%.1f%% of Americans)" % (ca * 100.0))
	r.check(countries.size() >= 15 and int(countries.get("Serbia", 0)) > int(countries.get("Australia", 0)), "4: abroad from many countries, the polo nations most (%d)" % countries.size())
	r.check(valid, "3/4: every city with its own state or country (no made-up pairs)")
	r.check(Hometowns.pick(rng).contains(", "), "1: \"City, State\" / \"City, Country\"")

## A hometown is a real pair from the tables (any of them: the broad pools or a school's local one).
func _valid(h: String) -> bool:
	if h == "Washington, D.C.":
		return true
	var city := h.get_slice(", ", 0)
	var place := h.get_slice(", ", 1)
	var pools: Array = []
	for e in Hometowns.STATES + Hometowns.COUNTRIES:
		if String(e[0]) == place:
			pools.append(e[2])
	if place == "California":
		pools.append(Hometowns.NORCAL)
		pools.append(Hometowns.SOCAL)
	if Hometowns.OTHER_STATES.has(place):
		pools.append(Hometowns.OTHER_STATES[place])
	if Hometowns.OTHER_COUNTRIES.has(place):
		pools.append(Hometowns.OTHER_COUNTRIES[place])
	for area in Hometowns.LOCAL:
		for pl in Hometowns.LOCAL[area]:
			if String(pl[0]) == place:
				pools.append(pl[1])
	return pools.any(func(list): return city in (list as Array))

# ------------------------------------------------------------------ rosters
func _rosters() -> void:
	Store.reset_for_tests()
	var c := Career.new_game("LIUB", "A", "B", 501)
	var everyone := 0
	var homed := 0
	var intl := 0
	var local_more := 0
	var schools := 0
	var rows: Array = []
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		var area := Hometowns.area_of(id)
		var us := 0
		var local := 0
		for p: PoloPlayer in t.roster:
			everyone += 1
			homed += 1 if p.home != "" and _valid(p.home) else 0
			if not Hometowns.is_us(p.home):
				intl += 1
				continue
			us += 1
			local += 1 if _in_area(p.home, area) else 0
		var share := float(local) / maxf(1.0, us)
		var base := _base_share(area)
		schools += 1
		local_more += 1 if share > base else 0
		rows.append("%s %d/%d local" % [id, local, us])
	print("    30 rosters: %d players, %.1f%% international; %d of %d schools more local than the broad pool" % [everyone, 100.0 * intl / everyone, local_more, schools])
	print("    " + ", ".join(rows))
	r.check(homed == everyone, "16.1: every player of all 30 starting rosters has a valid hometown")
	r.check(absf(float(intl) / everyone - 0.30) < 0.08, "5: the local lean leaves the 30%% international alone (%.1f%%)" % (100.0 * intl / everyone))
	r.check(local_more >= 22, "5: most schools' Americans lean local (%d of %d: a modest lean, small rosters vary)" % [local_more, schools])
	# future recruits: the broad pool
	var market := 0
	var market_local := 0
	for i in 2000:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + i
		var p := CollegeGen.make_prospect(rng, 3.0, "average", {})
		if Hometowns.is_us(p.home):
			market += 1
			market_local += 1 if _in_area(p.home, "New York") else 0
	r.check(absf(float(market_local) / market - _base_share("New York")) < 0.03, "5: recruits come from the broad pool (New York area %.1f%%)" % (100.0 * market_local / market))

func _in_area(h: String, area: String) -> bool:
	if area == "":
		return false
	var city := h.get_slice(", ", 0)
	var place := h.get_slice(", ", 1)
	for pl in Hometowns.LOCAL[area]:
		if String(pl[0]) == place and city in (pl[1] as Array):
			return true
	return false

## How often the broad pool gives an American from `area` (measured: 20,000 draws).
var _base_cache := {}
func _base_share(area: String) -> float:
	if area == "":
		return 0.0
	if _base_cache.has(area):
		return _base_cache[area]
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var us := 0
	var hit := 0
	for i in 20000:
		var h := Hometowns.pick(rng)
		if Hometowns.is_us(h):
			us += 1
			hit += 1 if _in_area(h, area) else 0
	_base_cache[area] = float(hit) / us
	return _base_cache[area]

# ------------------------------------------------------------------ saves and screens
func _saves(runner) -> void:
	r.check(Hometowns.shown("Princeton, NY") == "Princeton, New Jersey" and Hometowns.shown("Belgrade") == "Belgrade, Serbia"
		and Hometowns.shown("Newport Beach, CA") == "Newport Beach, California" and Hometowns.shown("Columbus, Ohio") == "Columbus, Ohio",
		"10: an old save's hometowns shown right (its words only; the saved text stays)")
	var c := Career.new_game("STAM", "A", "B", 77)
	var p: PoloPlayer = c.team().roster[2]
	var q: PoloPlayer = c.team().roster[3]
	var keep := [q.first, q.last, q.skin, q.attrs.duplicate(), q.attr_pot.duplicate(), q.year, q.id]
	var had := p.home
	q.home = ""   # (a player saved before he had one)
	q.region = ""
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	var q2: PoloPlayer = back.team().find_id(q.id)
	var p2: PoloPlayer = back.team().find_id(p.id)
	r.check(q2.home != "" and _valid(q2.home), "10: a saved player without one gets a hometown (%s)" % q2.home)
	r.check([q2.first, q2.last, q2.skin, q2.attrs, q2.attr_pot, q2.year, q2.id] == keep, "10: ...and nothing else of him changes (name, portrait's skin, attributes, ceilings, year)")
	r.check(p2.home == had, "10/14: a hometown he has is his for good")
	var again := Career.from_dict(JSON.parse_string(JSON.stringify(back.to_dict())))
	r.check(again.team().find_id(q.id).home == q2.home, "10: given once: saved and loaded again, the same")
	# his page: the hometown under his name
	Game.career = back
	Game.goto("player", {"id": p2.id})
	for i in 3:
		await runner.get_tree().process_frame
	var line: Node = Game.current_screen.find_child("Hometown", true, false)
	r.check(line != null and String(line.get_meta("text")) == Hometowns.shown(p2.home).to_upper(), "11: his profile shows it under his name (%s)" % (String(line.get_meta("text")) if line else "-"))
	Game.goto("title")
	await runner.get_tree().process_frame
	Game.career = null
