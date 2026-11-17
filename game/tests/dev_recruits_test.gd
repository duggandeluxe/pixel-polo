extends RefCounted
## THE SECRET DEV RECRUITS UPDATE (DevRecruits, DevArt, dev_lab): the spec's final checklist.
##   godot --headless --path game -- --test dev_recruits
##   godot --path game --resolution 480x270 -- --test dev_recruits_png <dir>

var r

func run(runner) -> void:
	r = runner
	print("DEV recruits")
	Store.reset_for_tests()
	Game.progress = Progression.fresh()
	DevRecruits.test_odds = 0
	_identity()
	_odds()
	_market_and_signing()
	_force_and_reset()
	_development()
	_gameplay()
	_saves()
	_cpu()
	_rotation()
	_prices()
	_impact()
	_numbers()
	await _screens()
	DevRecruits.test_odds = 0
	DevRecruits.test_pickup = -1.0
	Game.career = null

static func _career(seed_value: int) -> Career:
	var c := Career.new_game("SJCU", "A", "B", seed_value)
	c.queue.clear()
	Game.career = c
	return c

## The off-season as _ai_rosters meets it: every program's seniors gone (room on the CPU rosters).
static func _graduate(c: Career) -> void:
	for id in c.teams:
		var t: PoloTeam = c.teams[id]
		t.roster = t.roster.filter(func(p: PoloPlayer): return p.year < 4)

static func _devs(list: Array, key: String = "") -> Array:
	return list.filter(func(x): return (x.p as PoloPlayer).dev_recruit != "" and (key == "" or (x.p as PoloPlayer).dev_recruit == key))

# ------------------------------------------------------------------ their own caps
func _numbers() -> void:
	var c := _career(9101)
	var t := c.team()
	var had11: PoloPlayer = t.find(11)
	var had8: PoloPlayer = t.find(8)
	var b := DevRecruits.make("blake", c.new_id())
	var l := DevRecruits.make("logan", c.new_id())
	r.check(b.number == 11 and l.number == 8, "caps: Blake #11, Logan #8 from the start")
	Offseason.join(c, t, b)
	Offseason.join(c, t, l)
	var nums := {}
	for p: PoloPlayer in t.roster:
		nums[p.number] = int(nums.get(p.number, 0)) + 1
	r.check(b.number == 11 and l.number == 8 and nums.values().all(func(n): return n == 1), "caps: they wear #11 and #8 on a roster, no number twice")
	r.check(had11 == null or (had11.number != 11 and absi(had11.number - 11) <= 2 and had11.number != 8), "caps: #11's old owner moved to a nearby cap (%s)" % (had11.number if had11 else "-"))
	r.check(had8 == null or (had8.number != 8 and absi(had8.number - 8) <= 2 and had8.number != 11), "caps: #8's old owner moved to a nearby cap (%s)" % (had8.number if had8 else "-"))
	b.number = 30
	var back := Career.from_dict(c.to_dict())
	var b2: PoloPlayer = back.team().find_id(b.id)
	r.check(b2 != null and b2.number == 11, "caps: a save with Blake off #11 loads him back on it")
	Store.pro = true
	var t2: PoloTeam = c.teams[c.teams.keys().filter(func(id): return id != c.school)[0]]
	var held: PoloPlayer = t2.find(11)
	var b3 := DevRecruits.make("blake", c.new_id())
	Offseason.join(c, t2, b3)
	r.check(held == null or (held.number == 11 and b3.number != 11), "caps: with PIXEL POLO + nothing is forced")
	Store.pro = false
	Game.career = null
	print("  caps")

# ------------------------------------------------------------------ 4-7, 14: who they are
func _identity() -> void:
	var b := DevRecruits.make("blake")
	var l := DevRecruits.make("logan")
	r.check(b.first == "Blake" and b.last == "Duggan" and b.home == "San Antonio, Texas" and b.pos == PoloPlayer.Pos.DEFENDER
		and DevRecruits.role(b) == "2-Meter Defender / Utility", "4: Blake Duggan, San Antonio, Texas, 2-Meter Defender / Utility")
	r.check(l.first == "Logan" and l.last == "Baumann" and l.home == "Thousand Oaks, California" and l.pos == PoloPlayer.Pos.DRIVER
		and l.pos_text() == "ATK" and not l.lefty, "4: Logan Baumann, Thousand Oaks, California, ATK")
	r.check(b.attrs == {"pas": 3.0, "sho": 2.0, "str": 8.0, "dfn": 15.0} and b.attr_pot == {"pas": 4.0, "sho": 6.0, "str": 8.0, "dfn": 15.0},
		"5/6: Blake 2/3/8/15, ceilings 6/4/8/15 (%s %s)" % [b.attrs, b.attr_pot])
	r.check(l.attrs == {"pas": 6.0, "sho": 14.0, "str": 4.0, "dfn": 4.0} and l.attr_pot == {"pas": 8.0, "sho": 14.0, "str": 5.0, "dfn": 5.0},
		"5/6: Logan 14/6/4/4, ceilings 14/8/5/5 (%s %s)" % [l.attrs, l.attr_pot])
	r.check(is_equal_approx(b.rating10(), 7.0) and is_equal_approx(b.potential10(), 8.25) and b.stars == 4.0 and b.pot_stars == 5.0,
		"7: Blake 7.00 now (4 stars), 8.25 potential (5 stars)")
	r.check(is_equal_approx(l.rating10(), 7.0) and is_equal_approx(l.potential10(), 8.0) and l.stars == 4.0 and l.pot_stars == 5.0,
		"7: Logan 7.00 now (4 stars), 8.00 potential (5 stars): no six stars, nothing forced")
	r.check(b.trait_id == "" and l.trait_id == "" and Traits.best_for(b) == "" and Traits.best_for(l) == "", "no trait: nothing but their attributes")
	r.check(Recruiting.price_of(b) == 200 and Recruiting.price_of(l) == 200 and DevRecruits.PRICE == 200, "8/9: 200 PP each, never the formula's (nor its 110 cap)")
	r.check(DevArt.value_text(15.0) == "15/10" and DevArt.value_text(14.0) == "14/10" and DevArt.value_text(2.0) == "2/10", "10/11: 15/10 and 14/10")
	var plain := PoloPlayer.new()
	r.check(Attributes.cap(plain) == 10.0 and Attributes.cap(b) == Attributes.DEV_MAX and Attributes.DEV_MAX >= 15.0, "an ordinary player's cap is still 10")

# ------------------------------------------------------------------ 1: 1 in 1,000, each his own
func _odds() -> void:
	var c := _career(4401)
	var n := 200000
	var hits := {"blake": 0, "logan": 0}
	var both := 0
	var state0 := c.rng.state
	for i in n:
		c.refreshes = i
		var hb := DevRecruits.hit(c, "blake")
		var hl := DevRecruits.hit(c, "logan")
		hits.blake += int(hb)
		hits.logan += int(hl)
		both += int(hb and hl)
	c.refreshes = 0
	var exp := float(n) / DevRecruits.ODDS
	r.check(DevRecruits.ODDS == 1000 and absf(hits.blake - exp) < 4.0 * sqrt(exp) and absf(hits.logan - exp) < 4.0 * sqrt(exp),
		"1: about 1 in 1,000 a refresh each (%d and %d in %d, expected %d)" % [hits.blake, hits.logan, n, roundi(exp)])
	r.check(both <= 3, "1: rolled independently (both on the same refresh: %d, expected ~0.2)" % both)
	r.check(c.rng.state == state0, "the dice never draw from the career's (ordinary prospects are made as before)")
	# the same market with and without the roll: identical ordinary prospects
	var a := _career(4402)
	var a2 := _career(4402)
	DevRecruits.test_odds = 0
	a.credits = 500
	a2.credits = 500
	Recruiting.refresh(a)
	var before := a2.rng.state
	a2.refreshes += 1
	Recruiting.new_market(a2, true, false)
	r.check(a.market.map(func(x): return (x.p as PoloPlayer).last) == a2.market.map(func(x): return (x.p as PoloPlayer).last) and a.rng.state == a2.rng.state and before != a2.rng.state,
		"1: a refresh's roll leaves the ordinary prospects exactly as they'd be")

# ------------------------------------------------------------------ 2, 3, 8, 9, 21: the market
func _market_and_signing() -> void:
	var c := _career(4410)
	c.credits = 1000
	var y0 := Wallet.yellow(c)
	DevRecruits.test_odds = 1   # (every roll comes up: the odds themselves are checked above)
	var size := c.market.size()
	var cost := Recruiting.refresh_cost(c)
	r.check(Recruiting.refresh(c) == "", "2: a refresh")
	r.check(_devs(c.market, "blake").size() == 1 and _devs(c.market, "logan").size() == 1 and c.market.size() == size,
		"2: both can come up on a refresh, in ordinary places (the market stays %d)" % size)
	r.check(Wallet.yellow(c) == y0 - cost, "2: the refresh cost what it always does, nothing more")
	r.check(c.market.all(func(x): return int(x.price) == (200 if (x.p as PoloPlayer).dev_recruit != "" else Recruiting.price_of(x.p))),
		"9: DEV Recruits 200 PP, everyone else his own formula price")
	# DEV Recruits pin like anyone (the overhaul reversed the old block), within the same PIN_MAX
	var bl: Dictionary = _devs(c.market, "blake")[0]
	var lo: Dictionary = _devs(c.market, "logan")[0]
	r.check(Recruiting.can_pin(bl) and Recruiting.toggle_pin(c, bl) == "" and Recruiting.is_pinned(bl) and Recruiting.pinned(c).size() == 1,
		"PIN 2: a DEV Recruit pins")
	r.check(Recruiting.toggle_pin(c, bl) == "" and not Recruiting.is_pinned(bl) and Recruiting.pinned(c).is_empty(), "PIN 2: and unpins")
	var ord: Dictionary = c.market.filter(func(x): return (x.p as PoloPlayer).dev_recruit == "")[0]
	r.check(Recruiting.toggle_pin(c, ord) == "" and Recruiting.is_pinned(ord), "PIN: an ordinary recruit still pins")
	Recruiting.toggle_pin(c, bl)
	Recruiting.toggle_pin(c, lo)
	var rest: Array = c.market.filter(func(x): return not Recruiting.is_pinned(x))
	Recruiting.toggle_pin(c, rest[0])
	r.check(Recruiting.pinned(c).size() == Recruiting.PIN_MAX and Recruiting.toggle_pin(c, rest[1]) != "" and not Recruiting.is_pinned(rest[1]),
		"PIN: the same PIN_MAX (%d) with DEV Recruits among them" % Recruiting.PIN_MAX)
	Recruiting.toggle_pin(c, rest[0])
	var log0 := (c.dev_recruits.log as Array).size()
	# a paid refresh: pinned, both stay (no rotation roll), and it never makes a second copy of one
	Recruiting.refresh(c)
	r.check(_devs(c.market, "blake").size() == 1 and _devs(c.market, "logan").size() == 1 and ord in c.market and bl in c.market and lo in c.market,
		"PIN 3: pinned DEV Recruits survive the refresh (one Blake, one Logan), the ordinary pin kept")
	r.check((c.dev_recruits.log as Array).size() == log0 and DevRecruits.commits(c).is_empty(), "PIN 3: no pickup roll for a pinned one")
	# saves keep a DEV Recruit's pin and price; an older save (\"admin\", 70 PP) loads as a 200 PP DEV Recruit
	var saved := Recruiting.to_save(c.market)
	var loaded := Recruiting.from_save(JSON.parse_string(JSON.stringify(saved)))
	r.check(_devs(loaded).size() == 2 and _devs(loaded).all(func(x): return Recruiting.is_pinned(x) and int(x.price) == 200),
		"PIN 8: pinned DEV Recruits stay pinned through a save (200 PP)")
	for e in saved:
		var pd: Dictionary = e.p
		if pd.has("dev_recruit"):
			pd["admin"] = pd.dev_recruit
			pd.erase("dev_recruit")
			pd["dev"] = "admin"
			e["price"] = 70
	var old := Recruiting.from_save(JSON.parse_string(JSON.stringify(saved)))
	var old_ok := func(x): return int(x.price) == 200 and (x.p as PoloPlayer).dev == DevRecruits.DEV_PROFILE
	r.check(_devs(old).size() == 2 and _devs(old).all(old_ok) and _devs(old, "blake")[0].p.attr("dfn") == 15.0 and _devs(old, "logan")[0].p.attr("sho") == 14.0,
		"SAVE: an older save's Admin Recruits load as DEV Recruits, 70 PP -> 200, his 15 and 14 intact")
	r.check((_devs(old, "logan")[0].p as PoloPlayer).id == (lo.p as PoloPlayer).id, "SAVE: the same player id")
	Recruiting.toggle_pin(c, ord)
	# no roll on viewing, loading or reopening
	var snap := JSON.stringify(Recruiting.to_save(c.market))
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(JSON.stringify(Recruiting.to_save(back.market)) == snap and (back.dev_recruits.log as Array).size() == log0, "no roll on loading a save")
	# signing: exactly 200 off, once
	var y1 := Wallet.yellow(c)
	r.check(Recruiting.sign(c, bl) == "" and Wallet.yellow(c) == y1 - 200, "8/21: signing Blake takes exactly 200 PP (%d -> %d)" % [y1, Wallet.yellow(c)])
	r.check(Recruiting.sign(c, bl) != "" and Wallet.yellow(c) == y1 - 200, "8: never charged twice")
	r.check(DevRecruits.was_signed(c, "blake") and DevRecruits.where(c, "blake") == "incoming", "3: signed, remembered")
	Recruiting.refresh(c)
	Recruiting.refresh(c)
	r.check(_devs(c.market, "blake").is_empty() and _devs(c.incoming, "blake").size() == 1, "3: never a second Blake once he's signed")
	r.check(not (c.dev_recruits.log as Array).any(func(e): return String(e.how) == "rotated" and String(e.key) == "blake"), "5: a signed one never rolls")
	# not enough Polo Points: the ordinary refusal, nothing taken
	c.credits = 0
	var y2 := Wallet.yellow(c)
	if y2 < 200:
		r.check(lo in c.market and Recruiting.sign_block(c, lo) != "" and Recruiting.sign(c, lo) != "" and Wallet.yellow(c) == y2 and lo in c.market,
			"8: under 200 PP can't sign him (%d), and nothing is taken" % y2)
	DevRecruits.test_odds = 0

# ------------------------------------------------------------------ 20, 21: Developer Mode
func _force_and_reset() -> void:
	var c := _career(4420)
	c.credits = 200
	var y0 := Wallet.yellow(c)
	var before: Array = c.market.map(func(x): return (x.p as PoloPlayer).id)
	r.check(DevRecruits.force_spawn(c, "logan") == "", "20: FORCE SPAWN LOGAN")
	var after: Array = c.market.map(func(x): return (x.p as PoloPlayer).id)
	var changed := 0
	for i in before.size():
		changed += int(before[i] != after[i])
	r.check(Wallet.yellow(c) == y0 and c.market.size() == before.size() and changed == 1, "20: free, one place replaced, the market not remade")
	var lo: Dictionary = _devs(c.market, "logan")[0]
	r.check(int(lo.price) == 200 and lo.p.attrs == {"pas": 6.0, "sho": 14.0, "str": 4.0, "dfn": 4.0}, "20: the exact Logan, 200 PP to sign")
	r.check(DevRecruits.force_spawn(c, "logan").contains("already"), "20: no duplicate: a clear message")
	r.check(DevRecruits.force_spawn(c, "blake") == "" and _devs(c.market).size() == 2, "20: FORCE SPAWN BLAKE beside him")
	var bl: Dictionary = _devs(c.market, "blake")[0]
	r.check(Recruiting.sign(c, bl) == "" and Wallet.yellow(c) == y0 - 200, "21: a force-spawned DEV Recruit still costs 200 PP to sign")
	r.check(DevRecruits.force_spawn(c, "blake").contains("already"), "a signed one can't be spawned again")
	# reset: Logan (forced, unsigned) goes and the prospect he replaced comes back; Blake (signed) stays
	var lines := DevRecruits.reset_test_state(c)
	var ids: Array = c.market.map(func(x): return (x.p as PoloPlayer).id)
	r.check(_devs(c.market).is_empty() and ids.has(before[before.size() - 1]), "RESET: the forced Logan gone, the recruit he replaced back")
	r.check(_devs(c.incoming, "blake").size() == 1 and DevRecruits.was_signed(c, "blake"), "RESET: never a signed player")
	r.check(lines.any(func(l): return String(l).contains("never removed")), "RESET explains what it left (%s)" % " | ".join(lines))
	r.check(not DevRecruits.eligible(c, "logan") and not DevRecruits.eligible(c, "blake") and DevRecruits.generated(c, "logan"),
		"RESET: generation is permanent: neither can come up again")
	r.check(DevRecruits.status(c, "logan") == "NO LONGER ACTIVE" and DevRecruits.status(c, "blake") == "SIGNED — %s" % Colleges.short_name(c.team()).to_upper(),
		"DEV status: %s / %s" % [DevRecruits.status(c, "logan"), DevRecruits.status(c, "blake")])
	r.check(DevRecruits.force_spawn(c, "logan").contains("already been generated"), "Dev Mode can't bypass the once-per-save rule")
	r.check(DevRecruits.force_spawn(null, "blake") != "", "no career: a message, nothing made")

# ------------------------------------------------------------------ 17: training stays under the ceilings
func _development() -> void:
	var b := DevRecruits.make("blake")
	b.tokens = 20
	r.check(not Development.can_spend(b, "str") and not Development.can_spend(b, "dfn"), "17: Strength maxed at 8, Defense at 15")
	var n := 0
	while Development.spend(b, "sho"):
		n += 1
	r.check(n == 4 and b.attr("sho") == 6.0, "17: Shooting grows 2 -> 6 and stops (%d)" % n)
	Attributes.train(b, "passing", 500.0)
	Attributes.train(b, "strength", 500.0)
	r.check(b.attr("pas") == 4.0 and b.attr("str") == 8.0 and b.attr("dfn") == 15.0, "17: training never past a ceiling (%s)" % b.attrs)
	var l := DevRecruits.make("logan")
	l.tokens = 20
	for k in ["sho", "pas", "str", "dfn"]:
		while Development.spend(l, k):
			pass
	r.check(l.attrs == {"pas": 8.0, "sho": 14.0, "str": 5.0, "dfn": 5.0}, "17: Logan fully developed: 14/8/5/5 (%s)" % l.attrs)
	r.check(l.pot_stars == 5.0 and l.stars == 5.0, "7: Logan maxed out is a five-star (8.0)")
	# an ordinary player is still held at 10
	var o := DevRecruits.make("blake")
	o.dev_recruit = ""
	Attributes.sync(o)
	r.check(o.attr("str") == 8.0 and o.attr("dfn") == 10.0, "22: an ordinary player's attributes still stop at 10")

# ------------------------------------------------------------------ 16: gameplay reads the real numbers
func _gameplay() -> void:
	var b := DevRecruits.make("blake")
	var l := DevRecruits.make("logan")
	var ten := DevRecruits.make("logan")
	ten.dev_recruit = ""
	Attributes.sync(ten)   # (the same man, an ordinary 10 shooter)
	r.check(is_equal_approx(Attributes.eff_defense(b, 0.0), 15.0) and is_equal_approx(DefenseFormation.hot_capped(b, 0.0), 15.0),
		"16: Blake defends at 15, not 10")
	r.check(Attributes.unit(Attributes.eff_defense(b, 0.0)) > 1.15 and Attributes.unit(11.0) == 1.1, "16: his steals and lane reads past a 10's (an ordinary 11 unchanged)")
	r.check(Attributes.strength(b) == 8.0 and b.defense > b.strength and b.defense > 90, "16: Strength 8 in the 2 m battle, Defense past 90; the older mechanics' ratings %d/%d" % [b.strength, b.defense])
	r.check(Attributes.shot_pace(l) > Attributes.shot_pace(ten) and Attributes.release_mult(l) < Attributes.release_mult(ten) and l.shoot > ten.shoot,
		"16: Logan shoots harder and quicker than a 10 (%.1f/%.2f vs %.1f/%.2f)" % [Attributes.shot_pace(l), Attributes.release_mult(l), Attributes.shot_pace(ten), Attributes.release_mult(ten)])
	# the overhaul: his rating past 100 (the 10's) keeps counting in the shot's accuracy and pace,
	# up to Attributes.rating_top; the shot keeps its own bounds (no automatic goals)
	var top := Attributes.rating_top(l)
	r.check(float(l.shoot) > 100.0 and top == float(Attributes.DEV_LEGACY_TOP) and Attributes.rating_top(ten) == 100.0,
		"OP: Logan's shot rating %.1f is past 100; his read goes up to %d, a 10's stops at 100" % [float(l.shoot), roundi(top)])
	r.check(ShotModel.skill_spread(float(l.shoot), top) < ShotModel.skill_spread(100.0, 100.0) and ShotModel.skill_spread(float(l.shoot), top) > 0.5,
		"OP: his aim is tighter than any 10's, and still never exact (%.3f)" % ShotModel.skill_spread(float(l.shoot), top))
	r.check(Tempo.shooter_shot(Attributes.shot_pace(l), top) > Tempo.shooter_shot(100.0) and ShotModel.shot_speed(1.0, Attributes.shot_pace(l), {}, 0.0, top) > Tempo.SHOT_MAX
		and ShotModel.shot_speed(1.0, Attributes.shot_pace(l), {}, 0.0, top) < Tempo.SHOT_MAX + 1.0,
		"OP: his pace past a 100's, and his full pull past Tempo.SHOT_MAX, softly")
	r.check(Attributes.release_mult(l) >= Attributes.RELEASE_FLOOR, "16: within the release's own floor")
	# ordinary players exactly as before: a hot 10 is still read at 100
	r.check(ShotModel.skill_spread(115.0) == ShotModel.skill_spread(100.0) and Tempo.shooter_shot(115.0) == Tempo.shooter_shot(100.0),
		"22: an ordinary shooter is still held at 100 (Hot Stars and all)")
	var gk := AttrBench.player({}, true)
	var g14 := float(AttrBench.shots(l, null, gk, INF, 400, 3, AttrBench.SHOT_FROM, false, AttrBench.SHOT_AIM, true).goal)
	var g10 := float(AttrBench.shots(ten, null, gk, INF, 400, 3, AttrBench.SHOT_FROM, false, AttrBench.SHOT_AIM, true).goal)
	r.check(g14 > g10 and g14 < 1.0, "OP 14: Logan scores more than the same man at 10 (%.1f%% vs %.1f%%), never every time" % [g14 * 100.0, g10 * 100.0])
	r.check(is_equal_approx(Attributes.eff_defense(l, 0.0), 4.0) and Attributes.strength(l) == 4.0 and is_equal_approx(Attributes.pass_mod(b), Tempo.curve(Attributes.PASS_TABLE, 3.0)),
		"16: their weaknesses are real (Logan 4 defence and strength, Blake's passing 3)")
	# team ratings count the real numbers
	var c := _career(4430)
	var t := c.team()
	var field := t.starters().filter(func(p: PoloPlayer): return not p.is_keeper())
	var d0 := t.defense_score()
	var o0 := t.offense_score()
	var bk: PoloPlayer = field[field.size() - 1]
	var keep := bk.attrs.duplicate()
	var keep_pot := bk.attr_pot.duplicate()
	bk.dev_recruit = "blake"
	bk.attrs = b.attrs.duplicate()
	bk.attr_pot = b.attr_pot.duplicate()
	Attributes.sync(bk)
	r.check(t.defense_score() > d0 and is_equal_approx(t.defense_score() - d0, (15.0 * 0.65 + 8.0 * 0.35 - float(keep.dfn) * 0.65 - float(keep.str) * 0.35) / field.size()),
		"16: team DEF counts his 15/8 (%.2f -> %.2f)" % [d0, t.defense_score()])
	bk.dev_recruit = ""
	bk.attrs = keep
	bk.attr_pot = keep_pot
	Attributes.sync(bk)
	r.check(is_equal_approx(t.defense_score(), d0) and is_equal_approx(t.offense_score(), o0), "22: ordinary players exactly as before")

# ------------------------------------------------------------------ 10, 22: saves
func _saves() -> void:
	var b := DevRecruits.make("blake", 77)
	var d: Dictionary = JSON.parse_string(JSON.stringify(b.to_dict()))
	var back := PoloPlayer.from_dict(d)
	r.check(back.dev_recruit == "blake" and back.attrs == b.attrs and back.attr_pot == b.attr_pot and back.stars == 4.0 and back.pot_stars == 5.0 and back.home == b.home,
		"10: a DEV Recruit saves and loads exactly (15/10 and all)")
	var plain := PoloPlayer.from_dict(JSON.parse_string(JSON.stringify(DevRecruits.make("logan").to_dict())))
	plain.dev_recruit = ""
	r.check(not plain.to_dict().has("admin") and not plain.to_dict().has("dev_recruit") and b.to_dict().has("dev_recruit") and not b.to_dict().has("admin"), "22: an ordinary player's save has nothing new in it")
	var c := _career(4440)
	c.credits = 200
	DevRecruits.force_spawn(c, "logan")
	var lo: Dictionary = _devs(c.market, "logan")[0]
	Recruiting.sign(c, lo)
	var c2 := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(_devs(c2.incoming, "logan").size() == 1 and int(_devs(c2.incoming, "logan")[0].price) == 200 and DevRecruits.was_signed(c2, "logan")
		and (c2.dev_recruits.log as Array).size() == 1, "10: signed, his price and the spawn history survive a save")
	# he joins as a freshman, exactly as he is
	var p: PoloPlayer = _devs(c2.incoming, "logan")[0].p
	c2.incoming.clear()
	Offseason.join(c2, c2.team(), p)
	r.check(p.attrs == {"pas": 6.0, "sho": 14.0, "str": 4.0, "dfn": 4.0} and c2.team().find_id(p.id) == p, "joins the roster unchanged")
	var c3 := Career.from_dict(JSON.parse_string(JSON.stringify(c2.to_dict())))
	r.check(DevRecruits.where(c3, "logan") == "roster:" + c3.school and c3.team().find_id(p.id).attr("sho") == 14.0, "roster saves keep his 14")
	# an older save (no dev_recruits): loads, nothing made
	var old := c.to_dict()
	old.erase("dev_recruits")
	var c4 := Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	r.check(c4 != null and DevRecruits.eligible(c4, "blake") and c4.market.size() == c.market.size(), "22: an older save loads as it was")

# ------------------------------------------------------------------ CPU recruitment, generated once
func _cpu() -> void:
	# 5: the CPU pool's roll is ONE central die a key an off-season, 1 in 2,000, whatever the schools
	var c := _career(4470)
	var n := 100000
	var hits := 0
	for i in n:
		c.year = 3000 + i
		hits += int(DevRecruits.cpu_hit(c, "blake"))
	var exp := float(n) / DevRecruits.CPU_ODDS
	r.check(absf(hits - exp) < 4.0 * sqrt(exp), "CPU 4/5: one central roll, about 1 in 2,000 (%d in %d, expected %d)" % [hits, n, roundi(exp)])
	c = _career(4471)
	_graduate(c)
	DevRecruits.test_odds = 1
	var lines := DevRecruits.cpu_recruit(c)
	var sb := DevRecruits.school_of(c, "blake")
	var sl := DevRecruits.school_of(c, "logan")
	r.check(lines.size() == 2 and sb != "" and sl != "" and sb != c.school and sl != c.school, "CPU 1/2: generated into the CPU pool, both signed by CPU schools (%s, %s)" % [sb, sl])
	var bp: PoloPlayer = (c.teams[sb] as PoloTeam).roster.filter(func(p: PoloPlayer): return p.dev_recruit == "blake")[0]
	r.check(bp.attrs == {"pas": 3.0, "sho": 2.0, "str": 8.0, "dfn": 15.0} and bp.attr_pot.dfn == 15.0, "CPU 3: exactly himself on a CPU roster")
	var count := 0
	for id in c.teams:
		count += (c.teams[id] as PoloTeam).roster.filter(func(p: PoloPlayer): return p.dev_recruit == "blake").size()
	r.check(count == 1, "CPU: one Blake in the whole league")
	r.check(DevRecruits.status(c, "blake") == "SIGNED — %s" % Colleges.short_name(c.teams[sb]).to_upper(), "CPU 10: status names his school (%s)" % DevRecruits.status(c, "blake"))
	# 6/7: never again, whatever happens to him
	DevRecruits.cpu_recruit(c)
	Recruiting.refresh(c)
	r.check(_devs(c.market).is_empty() and DevRecruits.force_spawn(c, "blake").contains("already been generated"), "CPU 6/11: never generated twice (rolls and force spawn)")
	(c.teams[sb] as PoloTeam).roster.erase(bp)   # (he graduates)
	Recruiting.refresh(c)
	DevRecruits.cpu_recruit(c)
	r.check(DevRecruits.status(c, "blake") == "NO LONGER ACTIVE" and DevRecruits.where(c, "blake") == "" and not DevRecruits.eligible(c, "blake"),
		"CPU 7: graduated, gone: NO LONGER ACTIVE, never regenerated")
	# the shared pool: a PINNED unsigned DEV Recruit stays on the market through refreshes, then the CPU signs that same player
	DevRecruits.test_odds = 0
	c = _career(4472)
	c.credits = 200
	DevRecruits.force_spawn(c, "logan")
	var lo: PoloPlayer = _devs(c.market, "logan")[0].p
	Recruiting.toggle_pin(c, _devs(c.market, "logan")[0])
	Recruiting.refresh(c)
	_graduate(c)
	r.check(_devs(c.market, "logan").size() == 1 and _devs(c.market, "logan")[0].p == lo, "3: pinned and unsigned, he stays in the pool through a refresh (the same player)")
	Offseason._ai_rosters(c)
	var at := DevRecruits.school_of(c, "logan")
	var lp: PoloPlayer = (c.teams[at] as PoloTeam).find_id(lo.id) if at != "" else null
	r.check(at != "" and at != c.school and lp == lo and lo.attrs == {"pas": 6.0, "sho": 14.0, "str": 4.0, "dfn": 4.0} and lo.dev_recruit == "logan",
		"CPU 2/3: the class closes, a CPU school signs that same Logan (id %d), exact (bench rules never lower him)" % lo.id)
	# 8: CPU teams play with his real numbers
	var t: PoloTeam = c.teams[at]
	r.check(Attributes.shot_pace(lo) > Attributes.shot_pace(DevRecruits.make("blake")) and lo.shoot > 99, "CPU 8: his 14 plays for a CPU team as for yours")
	# 12: save/load keeps the flags; an older save gets them back from who exists
	var c2 := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(DevRecruits.generated(c2, "logan") and not DevRecruits.generated(c2, "blake") and DevRecruits.school_of(c2, "logan") == at,
		"12: generation flags and his school survive a save")
	var old := c.to_dict()
	old.erase("dev_recruits")
	var c3 := Career.from_dict(JSON.parse_string(JSON.stringify(old)))
	r.check(DevRecruits.generated(c3, "logan") and not DevRecruits.generated(c3, "blake"), "12: an older save with Logan already in it: marked generated")
	r.check((c2.dev_recruits.generated as Dictionary).has("logan_baumann_generated"), "the flag is logan_baumann_generated")
	# 13: no admins, no change: _ai_rosters' CPU step does nothing for ordinary recruiting
	var c4 := _career(4473)
	var c5 := _career(4473)
	DevRecruits.mark_generated(c5, "blake")
	DevRecruits.mark_generated(c5, "logan")
	DevRecruits.cpu_recruit(c4)
	r.check(JSON.stringify(c4.teams[c4.teams.keys()[1]].to_dict()) == JSON.stringify(c5.teams[c5.teams.keys()[1]].to_dict()) and c4.rng.state == c5.rng.state,
		"13: ordinary CPU recruiting unchanged (the roll draws nothing from the career's dice)")
	t = t

# ------------------------------------------------------------------ the overhaul: rotated out
static func _count(c: Career, key: String) -> int:
	var n := 0
	for id in c.teams:
		n += (c.teams[id] as PoloTeam).roster.filter(func(p: PoloPlayer): return p.dev_recruit == key).size()
	n += _devs(c.market, key).size() + _devs(c.incoming, key).size()
	n += DevRecruits.commits(c).filter(func(e): return String(e.key) == key).size()
	return n

func _rotation() -> void:
	# 4: the die itself: 75%, its own (never the career's dice)
	var c := _career(4480)
	DevRecruits.force_spawn(c, "logan")
	var lp: PoloPlayer = _devs(c.market, "logan")[0].p
	var n := 20000
	var hits := 0
	var state0 := c.rng.state
	for i in n:
		c.refreshes = i
		hits += int(DevRecruits.pickup_hit(c, lp))
	c.refreshes = 0
	var sd := sqrt(n * 0.75 * 0.25)
	r.check(DevRecruits.PICKUP_CHANCE == 0.75 and absf(hits - n * 0.75) < 4.0 * sd and c.rng.state == state0,
		"4: an unpinned DEV Recruit rotated out: about 75%% signed (%d in %d)" % [hits, n])
	# the 75% side: the same Logan commits to a CPU program, once, no copy
	c = _career(4481)
	c.credits = 500
	DevRecruits.force_spawn(c, "logan")
	var rec: Dictionary = _devs(c.market, "logan")[0]
	lp = rec.p
	var pid := lp.id
	# nothing but a real refresh rolls: opening, scouting, pinning, previews, saves
	var log0 := (c.dev_recruits.log as Array).size()
	Recruiting.toggle_pin(c, rec)
	Recruiting.toggle_pin(c, rec)
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check((c.dev_recruits.log as Array).size() == log0 and (back.dev_recruits.log as Array).size() == log0 and _devs(back.market, "logan").size() == 1,
		"EXCEPTIONS: pinning, unpinning, saving and loading never roll")
	DevRecruits.test_pickup = 1.0
	r.check(Recruiting.refresh(c) == "", "4: the refresh that rotates him out")
	var at := DevRecruits.where(c, "logan")
	var team := DevRecruits.school_of(c, "logan")
	var rolled: Array = (c.dev_recruits.log as Array).filter(func(e): return String(e.how) == "rotated")
	r.check(_devs(c.market, "logan").is_empty() and at.begins_with("commit:") and team != "" and team != c.school and c.teams.has(team),
		"4: unpinned, rotated out and signed by a CPU program (%s)" % at)
	r.check(rolled.size() == 1 and String(rolled[0].outcome) == "cpu" and String(rolled[0].team) == team and int(rolled[0].pid) == pid, "5: one roll, logged")
	r.check(DevRecruits.commits(c)[0].p == lp and lp.id == pid and lp.attrs == {"pas": 6.0, "sho": 14.0, "str": 4.0, "dfn": 4.0} and lp.dev_recruit == "logan",
		"6: the same player (id %d), exactly himself" % pid)
	r.check(c.news.any(func(x): return String(x.t).contains("DEV RECRUIT SIGNED: Logan Baumann has committed to %s!" % Colleges.short_name(c.teams[team]))),
		"NEWS: DEV RECRUIT SIGNED: Logan Baumann has committed to %s!" % Colleges.short_name(c.teams[team]))
	r.check(DevRecruits.status(c, "logan") == "SIGNED — %s" % Colleges.short_name(c.teams[team]).to_upper(), "status: %s" % DevRecruits.status(c, "logan"))
	DevRecruits.test_odds = 1
	Recruiting.refresh(c)
	Recruiting.refresh(c)
	r.check((c.dev_recruits.log as Array).filter(func(e): return String(e.how) == "rotated" and String(e.key) == "logan").size() == 1 and _count(c, "logan") == 1
		and DevRecruits.force_spawn(c, "logan").contains("already been generated"), "5/6/17: never a second roll, never a second Logan")
	DevRecruits.test_odds = 0
	# saves keep the signing; the class closes and he joins that school's roster
	var c2 := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(DevRecruits.where(c2, "logan") == at and (DevRecruits.commits(c2)[0].p as PoloPlayer).id == pid and DevRecruits.generated(c2, "logan")
		and JSON.stringify(c2.to_dict()) == JSON.stringify(Career.from_dict(JSON.parse_string(JSON.stringify(c2.to_dict()))).to_dict()),
		"SAVE: the CPU signing survives a save (same id), and saves again unchanged")
	_graduate(c2)
	Offseason._ai_rosters(c2)
	var on: PoloPlayer = (c2.teams[team] as PoloTeam).find_id(pid)
	r.check(on != null and on.dev_recruit == "logan" and on.attr("sho") == 14.0 and on.year == 1 and DevRecruits.where(c2, "logan") == "roster:" + team
		and DevRecruits.commits(c2).is_empty() and _count(c2, "logan") == 1, "7: on the CPU roster with the class (a freshman, his 14), one Logan in the league")
	# the 25% side: gone from recruiting for good, never regenerated
	var c3 := _career(4482)
	c3.credits = 500
	DevRecruits.force_spawn(c3, "blake")
	DevRecruits.test_pickup = 0.0
	Recruiting.refresh(c3)
	var gone: Array = (c3.dev_recruits.log as Array).filter(func(e): return String(e.how) == "rotated")
	r.check(_devs(c3.market).is_empty() and DevRecruits.where(c3, "blake") == "" and gone.size() == 1 and String(gone[0].outcome) == "unsigned"
		and DevRecruits.status(c3, "blake") == "NO LONGER ACTIVE" and _count(c3, "blake") == 0, "7: the 25%: he leaves recruiting unsigned, on no team")
	DevRecruits.test_odds = 1
	DevRecruits.test_pickup = 1.0
	Recruiting.refresh(c3)
	_graduate(c3)
	Offseason._ai_rosters(c3)
	r.check(_count(c3, "blake") == 0 and not DevRecruits.eligible(c3, "blake") and DevRecruits.generated(c3, "blake")
		and DevRecruits.force_spawn(c3, "blake").contains("already been generated"), "17: never back, never regenerated (refresh rolls, CPU pool roll, force spawn)")
	DevRecruits.test_odds = 0
	DevRecruits.test_pickup = -1.0
	# a CPU program with no room at the class close: still signed (another with room), never lost or copied
	var c4 := _career(4483)
	DevRecruits.force_spawn(c4, "logan")
	DevRecruits.test_pickup = 1.0
	Recruiting.refresh(c4)
	DevRecruits.test_pickup = -1.0
	var t4 := DevRecruits.school_of(c4, "logan")
	_graduate(c4)
	var full: PoloTeam = c4.teams[t4]
	while full.roster.size() < c4.roster_cap(t4):
		full.roster.append(AttrBench.player({}))
	var lines := DevRecruits.cpu_recruit(c4)
	r.check(_count(c4, "logan") == 1 and DevRecruits.school_of(c4, "logan") != "" and DevRecruits.school_of(c4, "logan") != c4.school and lines.size() == 1,
		"7: his school full at the class close: another CPU program signs him (%s)" % DevRecruits.school_of(c4, "logan"))

# ------------------------------------------------------------------ the overhaul: prices
func _prices() -> void:
	var c := _career(4490)
	var hi := 0
	for i in 3000:
		hi = maxi(hi, int(Recruiting.new_recruit(c).price))
	var top := Recruiting.make(c.rng, 4.5, 5.0, "high", {}, PoloPlayer.Pos.GK)
	CollegeGen.grow_to(c.rng, top, 5.0)
	r.check(hi <= 110 and Recruiting.ORDINARY_MAX == 110, "9: no ordinary recruit over 110 PP (the most of 3,000: %d)" % hi)
	r.check(Recruiting.price_of(top) <= 110, "9: even a 4.5-star with five-star potential: %d PP" % Recruiting.price_of(top))
	var saved := [{"p": AttrBench.player({}).to_dict(), "price": 130, "legacy": false}, {"p": DevRecruits.make("blake", 5).to_dict(), "price": 70, "legacy": false},
		{"p": AttrBench.player({}).to_dict(), "price": 37, "legacy": false}]
	var loaded := Recruiting.from_save(saved)
	r.check(int(loaded[0].price) == 110 and int(loaded[1].price) == 200, "9/10: a saved 130 ordinary is 110; a saved DEV Recruit is 200 (never clamped to 110)")
	r.check(int(loaded[2].price) == 37, "Price Rebalance: a saved ordinary price is kept as it was, never recalculated (37, the formula now %d)" % Recruiting.price_of(loaded[2].p))
	var y := c.wallet()
	r.check(y >= 0 and c.wallet() == y, "no PP moved by pricing")

# ------------------------------------------------------------------ the overhaul: OP ATTRIBUTE IMPACT
func _impact() -> void:
	var c := _career(4495)
	var snap := JSON.stringify(c.to_dict())
	var state0 := c.rng.state
	var want := {"blake_dfn": [10.0, 15.0], "logan_sho": [10.0, 14.0]}
	for id in want:
		var res := DevImpact.run(id)
		r.check(float(res.base_v) == want[id][0] and float(res.dev_v) == want[id][1] and not (res.rows as Array).is_empty(),
			"12: %s compares %d against %d (%d rows)" % [id, roundi(want[id][0]), roundi(want[id][1]), (res.rows as Array).size()])
		r.check(bool(res.valid), "14: %s: every probability within 0..1, none certain" % id)
		r.check((res.rows as Array).any(func(x): return String(x.kind) == "CALC") and (res.rows as Array).any(func(x): return String(x.kind) == "SIM"),
			"11: %s shows both calculated and simulated values" % id)
		r.check(JSON.stringify(DevImpact.run(id)) == JSON.stringify(res), "13: %s: the same numbers every run (fixed seeds)" % id)
		var better: Array = (res.rows as Array).filter(func(x): return DevImpact.edge_sign(x) > 0)
		# (real engine results, so a SIM row may come out against him within its noise: shown as it is)
		var goals: Array = (res.rows as Array).filter(func(x): return String(x.label).begins_with("GOALS") or String(x.kind) == "CALC")
		r.check(better.size() >= 3 and goals.all(func(x): return DevImpact.edge_sign(x) >= 0),
			"OP: %s: the boost helps him (%d rows better; no calculated or goal row worse)" % [id, better.size()])
		for x in res.rows:
			print("    %-30s %10s %10s  %s  %s" % [x.label, DevImpact.fmt(x.base, x.fmt), DevImpact.fmt(x.dev, x.fmt), DevImpact.diff_text(x), x.kind])
		for t in res.notes:
			print("    NOTE " + String(t))
	# the controlled pair: only the attribute differs
	var a := DevImpact.subject("logan", "sho", 10.0)
	var b := DevImpact.subject("logan", "sho", 14.0)
	r.check(a.attrs.pas == b.attrs.pas and a.attrs.str == b.attrs.str and a.attrs.dfn == b.attrs.dfn and a.dev_recruit == b.dev_recruit and a.speed == b.speed
		and a.attrs.sho == 10.0 and b.attrs.sho == 14.0 and a.id == -1, "13: identical but for the one attribute (nobody's player)")
	r.check(JSON.stringify(c.to_dict()) == snap and c.rng.state == state0, "15: the comparisons change nothing in the dynasty")

# ------------------------------------------------------------------ 12-15, 18, 19: screens
func _screens() -> void:
	var tree: SceneTree = r.get_tree()
	var c := _career(4450)
	Game.settings.dev_mode = true
	DevRecruits.force_spawn(c, "blake")
	DevRecruits.force_spawn(c, "logan")
	var bl: Dictionary = _devs(c.market, "blake")[0]
	# THE GLITCH on the market: only the DEV Recruits' cards, never past the gaps between cards
	Game.goto("recruiting", {"tab": "MARKET"})
	for _i in 3:
		await tree.process_frame
	var mk = Game.current_screen
	var glitches: Array = mk.find_children("DevGlitch*", "", true, false)
	var mcards: Array = mk.find_children("Card_*", "", true, false)
	var dev_cards: Array = mcards.filter(func(b): return b.has_meta("glitch"))
	r.check(glitches.size() == 2 and dev_cards.size() == 2 and dev_cards.all(func(b): return (c.market.filter(func(x): return (x.p as PoloPlayer).id == int(b.get_meta("pid")))[0].p as PoloPlayer).dev_recruit != ""),
		"GLITCH 6: two glitches, both on DEV Recruits' cards (keyed on dev_recruit) (%d glitches, %d dev cards of %d)" % [glitches.size(), dev_cards.size(), mcards.size()])
	var clear := true
	for g in glitches:
		for b in mcards:
			if b != g.target and g.get_global_rect().intersects(b.get_global_rect()):
				clear = false
	r.check(clear, "GLITCH 2: no glitch rect touches a neighbouring card")
	r.check(glitches.size() == 2 and not glitches[0].get_global_rect().intersects(glitches[1].get_global_rect()), "GLITCH 2: two DEV cards' glitches never meet")
	r.check(glitches.all(func(g): return g.room.x + g.room.y + g.room.z + g.room.w > 0.0 and g.get_global_rect().encloses(Rect2(g.global_position + g.body.position, g.body.size))),
		"GLITCH 2: it reaches past the card (room %s)" % str(glitches.map(func(g): return g.room)))
	r.check(dev_cards.all(func(b): return int(b.get_meta("price")) == 200), "GLITCH 7: still 200 PP")
	Game.goto("player", {"id": (bl.p as PoloPlayer).id, "recruit": true})
	for _i in 3:
		await tree.process_frame
	var scr = Game.current_screen
	r.check(scr.find_child("DevLabel", true, false) == null, "GLITCH 4: no DEV RECRUIT label on his profile")
	var card = scr.find_child("Card", true, false)
	var pg = card.get_meta("glitch") if card != null and card.has_meta("glitch") else null
	r.check(pg is DevGlitch and pg.get_parent() == scr and pg.strength > 1.0 and pg.clip_contents,
		"GLITCH 3: the big card glitches (its own node on the screen, out of the page's clip; harder than the market's)")
	var right = scr.find_child("Card", true, false).get_parent().get_child(1)
	r.check(pg != null and pg.get_global_rect().end.x <= right.get_global_rect().position.x - DevGlitch.CLEAR,
		"GLITCH 3: it never reaches the Player Attributes / Recruiting panels")
	r.check(String(scr.find_child("Name_dfn", true, false).get_meta("value", "")) == "15/10" and String(scr.find_child("Name_sho", true, false).get_meta("value", "")) == "2/10",
		"10: DEFENSE 15/10 on his page")
	var price = scr.find_child("Price", true, false)
	r.check(price != null and String(price.get_meta("amount")) == "200", "8: 200 PP in his RECRUITING panel")
	var pin_b = scr.find_child("Pin", true, false)
	var sign_b = scr.find_child("Sign", true, false)
	r.check(pin_b != null and not pin_b.disabled and sign_b != null, "PIN 1: the PIN button is back on his page; SIGN RECRUIT still there")
	r.check(DevArt.fragments(2) == 2 * (3 + 2 * 2) and DevArt.SLICES == 4, "the corrupted bar: twice the glitch fragments and slices")
	# an ordinary prospect's page: none of it
	var plain: Dictionary = c.market.filter(func(x): return (x.p as PoloPlayer).dev_recruit == "")[0]
	Game.goto("player", {"id": (plain.p as PoloPlayer).id, "recruit": true})
	for _i in 3:
		await tree.process_frame
	scr = Game.current_screen
	r.check(scr.find_child("DevLabel", true, false) == null and String(scr.find_child("Name_str", true, false).get_meta("value", "")) == DevArt.value_text((plain.p as PoloPlayer).attr("str")),
		"13: an ordinary player's page: no DEV look, but his #/10 beside each attribute")
	r.check(scr.find_children("DevGlitch*", "", true, false).is_empty(), "GLITCH 6: no glitch on an ordinary prospect's page")
	r.check(scr.find_child("Pin", true, false) != null and not scr.find_child("Pin", true, false).disabled, "PIN: an ordinary prospect's PIN as before")
	# the dev lab: both, the real cards, nothing changed by looking
	var snap := JSON.stringify(c.to_dict())
	Game.goto("dev_lab")
	for _i in 3:
		await tree.process_frame
	scr = Game.current_screen
	r.check(scr.find_child("Card_blake", true, false) != null and scr.find_child("Card_logan", true, false) != null, "18: both in DEV RECRUITS")
	var row_texts: Array = scr.find_children("Attr_*", "", true, false).map(func(x): return String(x.get_meta("text")))
	r.check("STRENGTH: 8 — MAXED" in row_texts and "DEFENSE: 15/10 — MAXED" in row_texts and "SHOOTING: 14/10 — MAXED" in row_texts
		and "SHOOTING: 2 → 6" in row_texts and "PASSING: 6 → 8" in row_texts and "STRENGTH: 4 → 5" in row_texts, "18: the dev cards' lines (%s)" % ", ".join(row_texts))
	r.check(scr.find_children("Cost", "", true, false).all(func(x): return int(x.get_meta("price")) == 200), "18: 200 PP each")
	Game.goto("player", {"dev_preview": "logan"})
	for _i in 3:
		await tree.process_frame
	scr = Game.current_screen
	r.check(scr.find_child("DevLabel", true, false) == null and String(scr.find_child("Name_sho", true, false).get_meta("value", "")) == "14/10"
		and scr.find_child("Sign", true, false) == null, "18: the full profile preview (14/10, nothing to sign)")
	r.check(JSON.stringify(c.to_dict()) == snap, "19: previewing changes nothing in the dynasty")
	# the inspection screen: both selectable, the three tabs, whatever he is in the dynasty
	Game.goto("dev_lab")
	for _i in 3:
		await tree.process_frame
	scr = Game.current_screen
	r.check(scr.find_child("Pick_blake", true, false) != null and scr.find_child("Pick_logan", true, false) != null
		and scr.find_child("Force_blake", true, false) != null and scr.find_child("ResetTest", true, false) != null,
		"INSPECT 1: BLAKE DUGGAN and LOGAN BAUMANN to pick; FORCE SPAWN and RESET still there")
	scr.auto_run = false
	scr.inspect("blake")
	r.check(scr.find_child("Tab_ROSTER_PREVIEW", true, false) != null and scr.find_child("Tab_PLAYER_PROFILE", true, false) != null
		and scr.find_child("Tab_IN_GAME_EFFECTS", true, false) != null and scr.find_child("TestInGame", true, false) != null,
		"INSPECT 1: ROSTER PREVIEW | PLAYER PROFILE | IN-GAME EFFECTS and TEST IN GAME")
	# ROSTER PREVIEW: roster.gd's own card, its size, a copy that's his
	var rc = scr.find_child("RosterCard", true, false)
	var RosterScreen = load("res://src/ui/screens/roster.gd")
	r.check(rc != null and rc.custom_minimum_size == RosterScreen.CARD and (rc.get_meta("player") as PoloPlayer).dev_recruit == "blake"
		and scr.find_child("RosterCardZoom", true, false) != null and scr.find_child("ViewInRoster", true, false) != null,
		"INSPECT 2: the actual roster card (%s), the zoom and VIEW IN ROSTER" % str(RosterScreen.CARD))
	# the same looks wherever he's drawn: the preview copy and the dynasty's own
	var own: PoloPlayer = _devs(c.market, "blake")[0].p
	r.check(JSON.stringify(PlayerArt.looks(own)) == JSON.stringify(PlayerArt.looks(DevRecruits.make("blake")))
		and JSON.stringify(PlayerArt.looks(DevRecruits.make("blake"))) != JSON.stringify(PlayerArt.looks(DevRecruits.make("logan"))),
		"INSPECT 2: his permanent look: the preview copy's hair and face are his own")
	scr.tab = "PLAYER PROFILE"
	scr._render()
	r.check(scr.find_child("OpenProfile", true, false) != null and scr.find_child("StarsCurrent", true, false) != null
		and scr.find_child("StarsPotential", true, false) != null and scr.find_child("Card_blake", true, false) != null,
		"INSPECT 4: PLAYER PROFILE: his card, stars, attributes and OPEN FULL PROFILE")
	r.check(scr.find_children("Attr_*", "", true, false).map(func(x): return String(x.get_meta("text"))).has("DEFENSE: 15/10 — MAXED"),
		"INSPECT 4: 15/10, never clamped")
	# VIEW IN ROSTER: the real roster screen on a copy; your roster untouched
	Game.goto("dev_roster", {"key": "logan"})
	for _i in 3:
		await tree.process_frame
	scr = Game.current_screen
	var shown: PoloTeam = scr.team()
	r.check(shown != c.team() and shown.roster.any(func(q: PoloPlayer): return q.dev_recruit == "logan")
		and not c.team().roster.any(func(q: PoloPlayer): return q.dev_recruit != "") and shown.roster.size() == c.team().roster.size()
		and scr.find_children("Spot_*", "", true, false).size() >= 6 and scr.find_child("PreviewNote", true, false) != null,
		"INSPECT 3: VIEW IN ROSTER: him in a read-only copy of your roster grid (%d players)" % shown.roster.size())
	r.check(not scr.lift(DevRoster_id(), Vector2.ZERO), "INSPECT 3: nothing to drag in the preview")
	r.check(JSON.stringify(c.to_dict()) == snap, "INSPECT 11: VIEW IN ROSTER changes nothing in the dynasty")
	scr.on_back()
	for _i in 3:
		await tree.process_frame
	scr = Game.current_screen
	r.check(String(scr.pick) == "blake", "INSPECT: back from a preview to the same DEV Recruit")
	# IN-GAME EFFECTS: his own comparisons, side by side, nothing changed
	scr.auto_run = false
	scr.tab = "IN-GAME EFFECTS"
	scr.cmp_id = "blake_dfn"
	scr.result = {}
	scr._render()
	r.check(scr.find_child("RunComparison", true, false) != null and scr.find_child("Cmp_blake_str", true, false) == null
		and scr.find_child("Cmp_blake_dfn", true, false) != null and scr.find_child("Cmp_logan_sho", true, false) == null and scr.find_child("Hint", true, false) != null,
		"INSPECT 6: IN-GAME EFFECTS: Blake's Defense comparison and RUN COMPARISON")
	await scr._run_comparison()
	var rows: Array = scr.find_children("Row_*", "", true, false)
	r.check(rows.size() > 5 and scr.find_child("Validity", true, false) != null and Array(rows[0].get_meta("cells"))[2] == "15/10",
		"11: RUN COMPARISON shows 10/10 and 15/10 side by side (%d rows)" % rows.size())
	r.check(JSON.stringify(c.to_dict()) == snap, "15: running a comparison changes nothing in the dynasty")
	# TEST IN GAME: the real match engine, him in it, COMPARE TO 10/10, nothing changed
	var Lab = load("res://src/ui/screens/dev_test_lab.gd")
	for key in ["blake", "logan"]:
		for s in Lab.SCENARIOS[key]:
			var b: Dictionary = Lab.build_test(key, String(s[1]), {}, 31)
			var me: Swimmer = b.get("me")
			r.check(bool(b.ok) and b.play is Play and me != null and me.player.dev_recruit == key
				and me.player.attrs == DevRecruits.make(key).attrs and (b.play as Play).holder == b.holder,
				"TEST 9: %s %s: a real Play, him in it with his real attributes" % [key, s[1]])
	var lo: Dictionary = Lab.build_test("logan", "perimeter", {}, 31)
	var lt: Dictionary = Lab.build_test("logan", "perimeter", {"sho": 10.0}, 31)
	var pa: Array = (lo.play as Play).bodies().map(func(x: Swimmer): return x.pos)
	var pb: Array = (lt.play as Play).bodies().map(func(x: Swimmer): return x.pos)
	r.check(pa == pb and (lt.me as Swimmer).player.attrs.sho == 10.0 and (lo.me as Swimmer).player.attrs.sho == 14.0
		and (lt.me as Swimmer).player.attrs.pas == (lo.me as Swimmer).player.attrs.pas, "TEST 10: COMPARE TO 10/10: the same start, only Shooting differs")
	r.check(Lab.trial("logan", "perimeter", {}, 3) == Lab.trial("logan", "perimeter", {}, 3), "TEST 10: a trial on a seed is repeatable")
	Game.goto("dev_test_lab", {"key": "logan"})
	for _i in 4:
		await tree.process_frame
	scr = Game.current_screen
	r.check(scr.play != null and scr.me != null and scr.me.player.dev_recruit == "logan" and scr.find_child("RunTrials", true, false) != null
		and scr.find_child("Var_1", true, false) != null, "TEST 9: TEST IN GAME loads the match engine with him in it")
	var tally: Dictionary = await scr.run_trials()
	var n_dev := 0
	for k in tally.dev:
		n_dev += int(tally.dev[k])
	r.check(n_dev == Lab.TRIALS and tally.cmp_name == "SHO 10", "TEST 10: RUN TRIALS: %d pairs, DEV against SHO 10 (%s / %s)" % [Lab.TRIALS, str(tally.dev), str(tally.cmp)])
	for _i in 30:
		scr._process(1.0 / 60.0)
	r.check(JSON.stringify(c.to_dict()) == snap and _devs(c.market, "logan")[0].p.attrs.sho == 14.0, "TEST 11: testing in game changes nothing in the dynasty")
	scr.on_back()
	for _i in 3:
		await tree.process_frame
	r.check(Game.current_name == "dev_lab", "TEST: exit back to DEV RECRUITS")
	Game.goto("dev_lab")
	for _i in 2:
		await tree.process_frame
	r.check(String(Game.current_screen.pick) == "", "INSPECT: from Settings, the overview")
	Game.settings.dev_mode = false

static func DevRoster_id() -> int:
	return load("res://src/ui/screens/dev_roster.gd").DEV_ID

# ------------------------------------------------------------------ screenshots
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := _career(4460)
	Game.settings.dev_mode = true
	DevRecruits.force_spawn(c, "blake")
	DevRecruits.force_spawn(c, "logan")
	var snap := func(name: String) -> void:
		await tree.create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name))
	Game.goto("recruiting", {"tab": "MARKET"})
	await snap.call("a_market.png")
	for key in ["blake", "logan"]:
		var rec: Dictionary = _devs(c.market, key)[0]
		Game.goto("player", {"id": (rec.p as PoloPlayer).id, "recruit": true})
		await snap.call("a_profile_%s.png" % key)
	Game.goto("dev_lab")
	await snap.call("a_lab.png")
	var lab = Game.current_screen
	for key in ["blake", "logan"]:
		lab.auto_run = false
		lab.inspect(key)
		for t in ["ROSTER PREVIEW", "PLAYER PROFILE"]:
			lab.tab = t
			lab._render()
			await snap.call("a_inspect_%s_%s.png" % [key, t.split(" ")[1].to_lower()])
		lab.tab = "IN-GAME EFFECTS"
		for id in (["blake_dfn"] if key == "blake" else ["logan_sho"]):
			lab.cmp_id = id
			await lab._run_comparison()
			await snap.call("a_impact_%s.png" % id)
		Game.goto("dev_roster", {"key": key})
		await snap.call("a_view_in_roster_%s.png" % key)
		Game.goto("dev_test_lab", {"key": key})
		await tree.create_timer(1.5).timeout
		await snap.call("a_test_in_game_%s.png" % key)
		Game.goto("dev_lab", {"keep": true})
		await tree.process_frame
		lab = Game.current_screen
	# signed, joined: the roster card and his own page
	c.credits = 500
	for key in ["blake", "logan"]:
		var rec: Dictionary = _devs(c.market, key)[0]
		Recruiting.sign(c, rec)
		Offseason.join(c, c.team(), rec.p)
	c.incoming.clear()
	c.team().lineup = []
	Game.goto("roster")
	await snap.call("a_roster.png")
	var bp: PoloPlayer = c.team().roster.filter(func(p: PoloPlayer): return p.dev_recruit == "blake")[0]
	Game.goto("player", {"id": bp.id})
	await snap.call("a_player_blake.png")
	print("  shots")
	Game.settings.dev_mode = false
	Game.career = null

## THE DEV RECRUIT GLITCH, frame by frame (DevGlitch.live/clock: the animation at chosen times):
##   godot --path game --resolution 480x270 -- --test dev_glitch_png <dir>
static func glitch_shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := _career(4460)
	Game.settings.dev_mode = true
	DevRecruits.force_spawn(c, "blake")
	DevRecruits.force_spawn(c, "logan")
	var snap := func(name: String) -> void:
		for _i in 3:
			await tree.process_frame
		await RenderingServer.frame_post_draw
		runner.get_viewport().get_texture().get_image().save_png(out.path_join(name))
	# the first time from `t0` the screen's first glitch is in a burst (strong or not), or ambient
	var find := func(g: DevGlitch, want: String, t0: float) -> float:
		var t := t0
		while t < t0 + 120.0:
			var b: Dictionary = g._burst_at(t)
			if (want == "ambient" and b.is_empty()) or (not b.is_empty() and (want == "strong") == bool(b.strong)):
				return t + 0.01
			t += 0.02
		return t0
	var pages := [["market", "recruiting", {"tab": "MARKET"}]]
	for key in ["blake", "logan"]:
		pages.append(["profile_" + key, "player", {"id": (_devs(c.market, key)[0].p as PoloPlayer).id, "recruit": true}])
	for pg in pages:
		Game.goto(pg[1], pg[2])
		await tree.create_timer(0.6).timeout
		var gs: Array = Game.current_screen.find_children("DevGlitch*", "", true, false)
		DevGlitch.live = true
		var t := 0.0
		for i in 4:
			DevGlitch.clock = find.call(gs[0], "strong", t)
			t = DevGlitch.clock + 0.4
			await snap.call("g_%s_strong%d.png" % [pg[0], i])
		for i in 2:
			DevGlitch.clock = find.call(gs[0], "burst", t)
			t = DevGlitch.clock + 0.4
			await snap.call("g_%s_burst%d.png" % [pg[0], i])
		DevGlitch.clock = find.call(gs[0], "ambient", 3.0)
		await snap.call("g_%s_ambient.png" % pg[0])
		DevGlitch.live = false
		DevGlitch.clock = -1.0
		await snap.call("g_%s_still.png" % pg[0])
	print("  glitch shots")
	Game.settings.dev_mode = false
	Game.career = null
