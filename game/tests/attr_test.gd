extends RefCounted
## Retro Polo 2.0's player attributes (Attributes, docs "Complete Player Attribute, Goalkeeper,
## and Star Rating System"): the ratings (four averaged, stars by Attributes.STAR_STEPS, potential, fractions, the
## limits), what each attribute does in the pool (measured with AttrBench, the game's own code),
## the unified star bar, saves and older saves, recruits, upgrades, development and HOT form.
##   godot --headless --path game -- --test attrs

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("attributes")
	Store.reset_for_tests()
	_ratings()
	_limits()
	_star_bar()
	_passing()
	_shooting()
	_strength()
	_defense()
	_communication()
	_lunge()
	_blocking()
	_legs()
	_keeper_styles()
	_development()
	_form_separate()
	_new_players()
	_upgrades()
	_saves()
	_old_saves()
	await _screens()

func _p(vals: Dictionary, keeper := false, pots := {}, pos := PoloPlayer.Pos.UTILITY) -> PoloPlayer:
	return AttrBench.player(vals, keeper, pots, pos)

# ------------------------------------------------------------------ ratings
func _ratings() -> void:
	var f := _p({"pas": 8, "sho": 9, "str": 5, "dfn": 6})
	r.check(is_equal_approx(f.rating10(), 7.0) and is_equal_approx(f.stars, 4.0), "field: (8 + 9 + 5 + 6) / 4 = 7.0, 4 stars")
	var g := _p({"com": 8, "lun": 9, "blk": 7, "leg": 8}, true)
	r.check(is_equal_approx(g.rating10(), 8.0) and is_equal_approx(g.stars, 5.0), "keeper: (8 + 9 + 7 + 8) / 4 = 8.0, 5 stars")
	r.check(g.key_ratings() == Attributes.KEEPER and f.key_ratings() == Attributes.FIELD, "keepers and field players have their own four")
	var e := _p({"pas": 8, "sho": 7, "str": 5, "dfn": 6}, false, {"pas": 9, "sho": 9, "str": 8, "dfn": 8})
	r.check(is_equal_approx(e.rating10(), 6.5) and is_equal_approx(e.potential10(), 8.5), "the spec's example: CURRENT 6.5, POTENTIAL 8.5")
	r.check(is_equal_approx(e.stars, 3.5) and is_equal_approx(e.pot_stars, 5.0), "...3.5 and 5 stars")
	var table := [[0, 0.5], [2, 1.5], [4, 2.5], [5, 3.0], [6, 3.5], [7, 4.0], [8, 5.0], [9, 5.0], [10, 5.0]]
	var ok := true
	for row in table:
		var q := _p({"pas": row[0], "sho": row[0], "str": row[0], "dfn": row[0]})
		ok = ok and is_equal_approx(q.stars, float(row[1])) and is_equal_approx(Attributes.stars_of(q.rating10()), q.stars)
	r.check(ok, "stars from OVERALL across the star steps, 0 to 10")
	var odd := _p({"pas": 6.3, "sho": 7.1, "str": 4.85, "dfn": 5.0})
	r.check(is_equal_approx(odd.rating10(), (6.3 + 7.1 + 4.85 + 5.0) / 4.0) and is_equal_approx(odd.stars, 3.0), "fractional attributes average exactly (5.8125: 3 stars)")
	r.check(odd.ovr_text() == "5.81" and PlayerForm.star_text(odd.stars) == "3", "...and show to two decimals (%s, %s)" % [odd.ovr_text(), PlayerForm.star_text(odd.stars)])
	r.check(is_equal_approx(odd.overall(), Attributes.legacy_of(odd.rating10())), "the 0-100 overall the AI compares is the same OVERALL (one calculation)")

func _limits() -> void:
	var p := _p({"pas": 6}, false, {"pas": 7})
	Attributes.set_value(p, "pas", 9.0)
	r.check(is_equal_approx(p.attr("pas"), 7.0), "an attribute can't go past its ceiling")
	Attributes.set_ceiling(p, "pas", 4.0)
	r.check(is_equal_approx(Attributes.ceiling(p, "pas"), 7.0), "a ceiling can't go under its attribute")
	Attributes.set_ceiling(p, "pas", 14.0)
	r.check(is_equal_approx(Attributes.ceiling(p, "pas"), 10.0), "a ceiling never passes 10")
	Attributes.set_value(p, "pas", -3.0)
	r.check(is_equal_approx(p.attr("pas"), 0.0), "an attribute never goes under 0")
	var top := _p({"pas": 12, "sho": 12, "str": 12, "dfn": 12})
	r.check(top.rating10() <= 10.0 and top.stars <= 5.0, "OVERALL never passes 10, stars never 5")
	# the 0-100 ratings follow the attributes and nothing else
	var a := _p({"sho": 9, "pas": 3})
	r.check(a.shoot > a.passing and a.shoot > a.strength, "a 9 shooter shoots better than he passes (%d vs %d)" % [a.shoot, a.passing])

# ------------------------------------------------------------------ the unified star bar
func _star_bar() -> void:
	var f := Deck.star_fills(3.0, 4.25, PlayerForm.red_stars(PlayerForm.VERY_HOT))
	r.check(f.size() == Deck.STAR_PLACES, "five places, no more")
	var gold := 0.0
	var pot := 0.0
	var red := 0.0
	for i in Deck.STAR_PLACES:
		gold += float(f[i].gold)
		pot += float(f[i].pot)
		red += float(f[i].form) - float(f[i].gold)
	var calm := Deck.star_fills(3.25, 4.25, 0)
	var calm_gold := 0.0
	var calm_pot := 0.0
	for i in Deck.STAR_PLACES:
		calm_gold += float(calm[i].gold)
		calm_pot += float(calm[i].pot)
	r.check(is_equal_approx(calm_gold, 3.5) and is_equal_approx(calm_pot, 4.5), "3.25 / 4.25 drawn to the nearest half: 3.5 gold, 4.5 to POTENTIAL")
	r.check(is_equal_approx(red, 2.0) and is_equal_approx(gold, 3.0) and f[4].form_col == PlayerForm.FIRE_RED, "VERY HOT: two whole red stars after three gold")
	var half := Deck.star_fills(3.25, 4.25, PlayerForm.red_stars(PlayerForm.VERY_HOT))
	r.check(half.size() == 6 and is_equal_approx(float(half[3].gold), 0.5) and float(half[3].form) <= 0.5
		and float(half[4].form) > float(half[4].gold) and float(half[5].form) > float(half[5].gold),
		"a 3.5 VERY HOT: three gold, his half star kept, THEN two red (six places)")
	var five := Deck.star_fills(5.0, 5.0, PlayerForm.red_stars(PlayerForm.VERY_HOT))
	r.check(five.size() == Deck.STAR_PLACES + 2 and float(five[4].gold) >= 1.0 and float(five[5].form) > float(five[5].gold) and float(five[6].form) > float(five[6].gold),
		"a five-star VERY HOT: five gold, then two red (seven places)")
	var normal := Deck.star_fills(3.0, 5.0, 0)
	var empty_pot := 0
	for i in Deck.STAR_PLACES:
		if float(normal[i].pot) > float(normal[i].gold) and float(normal[i].form) <= float(normal[i].gold):
			empty_pot += 1
	r.check(empty_pot == 2, "NORMAL: three gold, two empty potential stars, no red")
	r.check(StarFx.form_place(3.0, 5.0, PlayerForm.HOT) == 3 and StarFx.changed_places(3.0, 5.0, PlayerForm.NORMAL, PlayerForm.HOT) == [3],
		"heating up turns the place after the gold red, nothing else")

# ------------------------------------------------------------------ field players
func _passing() -> void:
	var expect := [[0, -0.10], [2, -0.06], [5, 0.0], [8, 0.06], [10, 0.10], [6.5, 0.03]]
	var ok := true
	for e in expect:
		ok = ok and is_equal_approx(Attributes.pass_mod(_p({"pas": e[0]})), float(e[1]))
	r.check(ok, "PASSING's catch-and-shoot edge: -10% .. +10%, straight lines between the spec's points")
	var gk := _p({}, true)
	var shooter := _p({})
	# (their keeper the right way, the ball out towards his fingertips: against a guess the edge
	# only tells when he guessed it, and there it's his reach it takes off him)
	var hi := AttrBench.shots(shooter, _p({"pas": 10}), gk, 0.2, 3000, 7, AttrBench.SHOT_FROM, true, 1.2)
	var mid := AttrBench.shots(shooter, _p({}), gk, 0.2, 3000, 7, AttrBench.SHOT_FROM, true, 1.2)
	var lo := AttrBench.shots(shooter, _p({"pas": 0}), gk, 0.2, 3000, 7, AttrBench.SHOT_FROM, true, 1.2)
	r.check(hi.goal > mid.goal and mid.goal > lo.goal, "a catch and shoot goes in more off a better passer (%.2f / %.2f / %.2f)" % [hi.goal, mid.goal, lo.goal])
	var no_cs_hi := AttrBench.shots(shooter, _p({"pas": 10}), gk, INF, 600)
	var no_cs_lo := AttrBench.shots(shooter, _p({"pas": 0}), gk, INF, 600)
	r.check(is_equal_approx(no_cs_hi.goal, no_cs_lo.goal), "no catch and shoot, no passing edge (the same shots)")
	var ctx := AttrBench.shot_ctx(shooter, _p({"pas": 10}), gk, 0.2)
	var rng := RandomNumberGenerator.new()
	var res := ShotModel.resolve(AttrBench.SHOT_FROM, Geo.GOAL_Y, 0.8, 60.0, 9, [], Geo.GOAL_Y, 60.0, rng, false, {}, ctx)
	r.check(is_equal_approx(float(res.pass_edge), 0.10), "the edge comes from the passer's rating")

func _shooting() -> void:
	r.check(is_equal_approx(Attributes.release_mult(_p({"sho": 0})), 1.2) and is_equal_approx(Attributes.release_mult(_p({"sho": 5})), 1.0)
		and is_equal_approx(Attributes.release_mult(_p({"sho": 10})), 0.8), "SHOOTING: 20% slower at 0, normal at 5, 20% faster at 10")
	r.check(AttrBench.windup(_p({"sho": 10})) < AttrBench.windup(_p({})) and AttrBench.windup(_p({})) < AttrBench.windup(_p({"sho": 0})),
		"their wind-up at your goal is quicker for a better shooter")
	var gk := _p({}, true)
	r.check(AttrBench.reaction(gk, _p({"sho": 10})) > AttrBench.reaction(gk, _p({"sho": 0})) + 0.05, "the keeper reacts later to a quick release")
	# the release is its own thing: the ball's pace isn't in it
	var rng := RandomNumberGenerator.new()
	var a := ShotModel.resolve(AttrBench.SHOT_FROM, Geo.GOAL_Y + 1.0, 0.8, 60.0, 9, [], Geo.GOAL_Y, 60.0, rng, false, {}, {"release": 0.05})
	var b := ShotModel.resolve(AttrBench.SHOT_FROM, Geo.GOAL_Y + 1.0, 0.8, 60.0, 9, [], Geo.GOAL_Y, 60.0, rng, false, {}, {"release": -0.05})
	r.check(is_equal_approx(float(a.speed), float(b.speed)), "release speed never changes the ball's speed (Tempo's shot pace stays)")
	var p := Play.new(League.make_team(1), League.make_team(2), Play.Kind.HALF_COURT, RandomNumberGenerator.new())
	p.holder.player = _p({"sho": 10})
	p.raise_ball(true)
	p._ease_arm(0.05)
	var fast := p.holder.arm
	p.holder.arm = 0.0
	p.holder.player = _p({"sho": 0})
	p._ease_arm(0.05)
	r.check(fast > p.holder.arm, "a better shooter gets the ball up quicker (%.2f vs %.2f)" % [fast, p.holder.arm])

func _strength() -> void:
	var avg := _p({})
	var strong := AttrBench.centre(_p({"str": 10}), avg)
	var even := AttrBench.centre(_p({}), avg)
	var weak := AttrBench.centre(_p({"str": 0}), avg)
	r.check(strong.win < even.win and even.win < weak.win, "a stronger centre wins inside water sooner (%.1f / %.1f / %.1f s)" % [strong.win, even.win, weak.win])
	var wall := AttrBench.centre(avg, _p({"str": 10}))
	r.check(wall.win > even.win and wall.seal < even.seal, "a stronger guard holds the front longer and wins it back sooner")
	var smart := AttrBench.centre(avg, _p({"dfn": 10}))
	r.check(smart.win > even.win and smart.switch < even.switch, "a better defender holds him off longer and gets round quicker (Defense counts too)")
	r.check(strong.win >= PlayAI.CENTER_WIN.x and weak.win <= PlayAI.CENTER_WIN.y, "...still inside the 2 m battle's own 5-10 s")
	var press := AttrBench.foul_rate(avg, _p({"str": 10}))
	var soft := AttrBench.foul_rate(avg, _p({"str": 0}))
	r.check(press < AttrBench.foul_rate(avg, avg) and soft > AttrBench.foul_rate(avg, avg), "a stronger man on the ball is fouled off it later")

func _defense() -> void:
	var hi := AttrBench.intercept(_p({"dfn": 10}))
	var mid := AttrBench.intercept(_p({}))
	var lo := AttrBench.intercept(_p({"dfn": 0}))
	r.check(hi > mid and mid > lo, "a better defender picks off more of a pass going through him (%.3f / %.3f / %.3f)" % [hi, mid, lo])
	var f := AttrBench.foul_rate(_p({"dfn": 10}), _p({}))
	r.check(is_equal_approx(f / AttrBench.foul_rate(_p({}), _p({})), 1.2), "forcing a foul: (Defense - Strength) x 4% (10 vs 5: +20%)")
	# no long-range steals: a pass 1.5 m from the best defender in the game is never his
	var steals := 0
	for i in 40:
		var b := AttrBench.centre_play(_p({}, false, {}, PoloPlayer.Pos.CENTER), _p({}), null, 100 + i)
		var p: Play = b.play
		var d := p.defenders[2]
		d.player = _p({"dfn": 10})
		for o in p.defenders:
			if o != d:
				o.pos = Vector2(2.0, 2.0)
		p.keeper_in = false
		var from := p.holder.pos
		var mate: Swimmer = p.attackers[0] if p.attackers[0] != p.holder else p.attackers[1]
		var to := mate.pos
		var dir := (to - from).normalized()
		d.pos = from.lerp(to, 0.5) + dir.orthogonal() * 1.5
		d.target = d.pos
		p._pass(to, mate)
		for _s in 90:
			p.step(1.0 / 30.0)
			d.pos = from.lerp(to, 0.5) + dir.orthogonal() * 1.5
			if p.over or p.ball.state != Ball.State.PASS:
				break
		if p.over and String(p.result.get("outcome", "")) == "steal":
			steals += 1
	r.check(steals == 0, "Defense 10 still can't pick off a pass 1.5 m away (%d of 40)" % steals)

# ------------------------------------------------------------------ goalkeepers
func _communication() -> void:
	r.check(is_equal_approx(Attributes.comm_bonus(_p({"com": 0}, true)), -0.5) and is_equal_approx(Attributes.comm_bonus(_p({"com": 10}, true)), 0.5)
		and is_zero_approx(Attributes.comm_bonus(_p({}, true))), "COMMUNICATION: -0.5 .. +0.5 effective Defense, 0 at 5")
	r.check(is_zero_approx(Attributes.comm_bonus(_p({"pas": 10}))), "a field player in goal gives no organising bonus")
	var mate := _p({})
	var loud := AttrBench.intercept(mate, _p({"com": 10}, true))
	var quiet := AttrBench.intercept(mate, _p({"com": 0}, true))
	r.check(loud > AttrBench.intercept(mate, _p({}, true)) and quiet < AttrBench.intercept(mate, _p({}, true)), "his defenders pick off more with a better communicator behind them")
	r.check(loud - quiet < AttrBench.intercept(_p({"dfn": 10})) - AttrBench.intercept(_p({"dfn": 0})), "...but much less than their own Defense does (small)")
	var before := [mate.attrs.duplicate(), mate.attr_pot.duplicate(), mate.stars, mate.pot_stars]
	AttrBench.foul_rate(mate, _p({}), _p({"com": 10}, true))
	r.check(mate.attrs == before[0] and mate.attr_pot == before[1] and mate.stars == before[2] and mate.pot_stars == before[3], "it never touches a teammate's attributes or ceilings")
	# added once: the effective Defense is his Defense plus the bonus, nothing more
	var d := Attributes.eff_defense(mate, 0.5)
	r.check(is_equal_approx(d, 5.5) and is_equal_approx(Attributes.eff_defense_legacy(mate, 0.5) - mate.live("defense"), 0.5 * (Attributes.SPREAD * 0.75 + 0.45)), "the bonus is added once (5 -> 5.5)")
	var b := AttrBench.centre_play(_p({}), _p({}), _p({"com": 10}, true))
	var p: Play = b.play
	r.check(is_equal_approx(p.comm(), 0.5), "in the pool: their keeper in goal, +0.5")
	p.keeper.out = true
	r.check(is_zero_approx(p.comm()), "...and nothing once he isn't")

func _lunge() -> void:
	var fast := AttrBench.dive(_p({"lun": 10}, true))
	var avg := AttrBench.dive(_p({}, true))
	var slow := AttrBench.dive(_p({"lun": 0}, true))
	r.check(is_equal_approx(fast.extend / avg.extend, 0.8) and is_equal_approx(slow.extend / avg.extend, 1.2), "LUNGE SPEED: his dive 20% quicker at 10, 20% slower at 0")
	r.check(is_equal_approx(fast.span, avg.span) and is_equal_approx(slow.span, avg.span), "...but never further")
	var shooter := _p({})
	r.check(AttrBench.reaction(_p({"lun": 10}, true), shooter) < AttrBench.reaction(_p({}, true), shooter), "an AI keeper with quick feet reacts sooner")
	# (from range he has time whatever his feet; right in close nobody sees it in time: it's the ones
	# in between, where seeing it a beat sooner gets him there, that a quick keeper saves)
	var close := Vector2(26.0, 9.4)
	var ai_hi: float = AttrBench.shots(shooter, null, _p({"lun": 10}, true), INF, AttrBench.N, 7, close).save
	var ai_lo: float = AttrBench.shots(shooter, null, _p({"lun": 0}, true), INF, AttrBench.N, 7, close).save
	r.check(ai_hi > ai_lo, "...and saves more close in (%.2f vs %.2f)" % [ai_hi, ai_lo])

func _blocking() -> void:
	var hi := AttrBench.blocking(_p({"blk": 10}, true), 0.95)
	var mid := AttrBench.blocking(_p({}, true), 0.95)
	var lo := AttrBench.blocking(_p({"blk": 0}, true), 0.95)
	r.check(hi > mid and mid > lo, "BLOCKING: a fingertip save held more often (%.2f / %.2f / %.2f)" % [hi, mid, lo])
	r.check(AttrBench.blocking(_p({"blk": 10}, true), 0.97) < 1.0, "never a certain save at his fingertips, however good his hands")
	r.check(is_equal_approx(AttrBench.blocking(_p({}, true), 0.3), 1.0) and AttrBench.blocking(_p({"blk": 0}, true), 0.3) < 0.95,
		"a ball into his body is an average keeper's; a poor blocker fumbles even those")
	r.check(is_zero_approx(AttrBench.blocking(_p({"blk": 10}, true), 1.3, 200)), "out of his reach it's in, however good his hands")
	r.check(is_equal_approx(Attributes.hold_chance(0.3, -0.15) / Attributes.hold_chance(0.3, 0.0), 0.85)
		and Attributes.hold_chance(1.0, 0.15) > Attributes.hold_chance(1.0, 0.0) and Attributes.hold_chance(1.0, 0.15) < 1.0,
		"(B - 5) x 3%: 0 blocking 15% less; 10 holds more at his fingertips, never all")
	var ai_hi: float = AttrBench.shots(_p({}), null, _p({"blk": 10}, true)).save
	var ai_lo: float = AttrBench.shots(_p({}), null, _p({"blk": 0}, true)).save
	r.check(ai_hi > ai_lo, "an AI keeper with good hands saves more (%.2f vs %.2f)" % [ai_hi, ai_lo])

func _legs() -> void:
	var strong := AttrBench.dive(_p({"leg": 10}, true))
	var avg := AttrBench.dive(_p({}, true))
	var weak := AttrBench.dive(_p({"leg": 0}, true))
	r.check(strong.span > avg.span and avg.span > weak.span, "LEG STRENGTH: more reach (%.2f / %.2f / %.2f m)" % [strong.span, avg.span, weak.span])
	r.check(is_equal_approx(strong.extend, avg.extend), "...not a quicker dive")
	r.check(strong.window > avg.window and avg.window > weak.window, "strong legs stay up at full stretch longer (%.2f / %.2f / %.2f s)" % [strong.window, avg.window, weak.window])
	r.check(strong.window <= 0.56 and weak.window >= 0.12, "...but even the strongest legs come down, and the weakest still get a moment up")
	var d := KeeperDive.new(KeeperDive.RIGHT, Geo.GOAL_Y, 0.7, 0.5)
	d.advance(2.0)
	r.check(d.done() and d.reach() == 0.0, "a dive never stays up: two seconds on he's back in the water, no reach left")

func _keeper_styles() -> void:
	var quick := _p({"com": 5, "lun": 10, "blk": 8, "leg": 5}, true)
	var power := _p({"com": 6, "lun": 4, "blk": 8, "leg": 10}, true)
	var leader := _p({"com": 10, "lun": 6, "blk": 7, "leg": 5}, true)
	var dq := AttrBench.dive(quick)
	var dp := AttrBench.dive(power)
	var dl := AttrBench.dive(leader)
	r.check(dq.extend < dl.extend and dl.extend < dp.extend, "the quick-reaction keeper dives quickest, the powerful one slowest")
	r.check(dp.span > dq.span and dp.window > dq.window, "the powerful keeper reaches furthest and stays up longest")
	r.check(Attributes.comm_bonus(leader) > Attributes.comm_bonus(power) and Attributes.comm_bonus(power) > Attributes.comm_bonus(quick), "the defensive leader organises best")

# ------------------------------------------------------------------ development, form
func _development() -> void:
	# a point of training moves his OVERALL exactly as far as it moved the old overall (1.8 a point)
	var p := _p({"pas": 5, "sho": 5, "str": 5, "dfn": 5}, false, {"pas": 9, "sho": 9, "str": 9, "dfn": 9}, PoloPlayer.Pos.WING)
	var before := p.rating10()
	Attributes.train(p, "shoot", 1.0)
	r.check(is_equal_approx(p.rating10() - before, 0.32 / 1.8), "one training point: the same development speed as before (%.4f)" % (p.rating10() - before))
	var q := _p({"pas": 5, "sho": 7, "str": 5, "dfn": 5}, false, {"pas": 5, "sho": 7, "str": 9, "dfn": 5})
	for _i in 100:
		Attributes.train(q, "shoot", 1.0)
	r.check(is_equal_approx(q.attr("sho"), 7.0) and is_equal_approx(q.attr("str"), 9.0) and is_equal_approx(q.rating10(), q.potential10()),
		"training never passes a ceiling (what it can't take goes where there's room)")
	var c := Career.new_game("GWU", "A", "B", 71)
	for _w in 4:
		while c.has_game():
			c.sim_my_game()
		c.queue.clear()
		c.end_week()
	var bad := 0
	var grew := 0
	for id in c.teams:
		for pl: PoloPlayer in c.teams[id].roster:
			for k in pl.key_ratings():
				if pl.attr(k) > Attributes.ceiling(pl, k) + 1e-6 or pl.attr(k) < 0.0 or Attributes.ceiling(pl, k) > 10.0:
					bad += 1
			if not is_equal_approx(pl.stars, Attributes.stars_of(pl.rating10())) or not is_equal_approx(pl.pot_stars, Attributes.stars_of(pl.potential10())):
				bad += 1
			if pl.overall() > pl.star_base + 0.001:
				grew += 1
	r.check(bad == 0, "four weeks of practice: every attribute inside its limits, stars always from its average")
	r.check(grew >= 5, "...and players grew (%d)" % grew)

func _form_separate() -> void:
	var c := Career.new_game("BUCK", "A", "B", 81)
	var t: PoloTeam = c.team()
	var before := {}
	for p: PoloPlayer in t.starters():
		before[p.id] = [p.attrs.duplicate(), p.attr_pot.duplicate(), p.stars, p.pot_stars]
	var lines := {}
	for p: PoloPlayer in t.starters():
		lines[p.id] = {"gk": true, "sv": 20} if p.is_keeper() else {"g": 6, "sh": 6}
	PlayerForm.grade_team(t, lines, {})
	var after_one := t.starters().filter(func(p): return p.form_state() != PlayerForm.NORMAL).size()
	PlayerForm.grade_team(t, lines, {})
	PlayerForm.grade_team(t, lines, {})
	var same := true
	var hot := 0
	for p: PoloPlayer in t.starters():
		var b: Array = before[p.id]
		same = same and p.attrs == b[0] and p.attr_pot == b[1] and p.stars == b[2] and p.pot_stars == b[3]
		if p.form_state() == PlayerForm.HOT:
			hot += 1
	r.check(after_one == 0 and hot == 7 and same, "one big game isn't enough, three make them HOT; attributes, ceilings and stars stay as they were")
	var p: PoloPlayer = t.starters()[2]
	r.check(is_equal_approx(p.eff_stars(), p.stars + 0.5) and p.live("defense") > p.defense, "HOT: EFFECTIVE +0.5, his 0-100 ratings up in a game")
	r.check(is_equal_approx(Attributes.pass_mod(p), Tempo.curve(Attributes.PASS_TABLE, p.attr("pas") + Attributes.hot_bonus(p))) and is_equal_approx(Attributes.hot_bonus(p), 0.5),
		"the attribute mechanics read his attributes plus his Hot bonus once (Hot Star Gameplay update)")

# ------------------------------------------------------------------ players new and old
func _valid(p: PoloPlayer) -> bool:
	if p.key_ratings() != (Attributes.KEEPER if p.is_keeper() else Attributes.FIELD):
		return false
	for k in p.key_ratings():
		if not p.attrs.has(k) or not p.attr_pot.has(k) or p.attr(k) < 0.0 or p.attr(k) > 10.0 or Attributes.ceiling(p, k) < p.attr(k) - 1e-6 or Attributes.ceiling(p, k) > 10.0:
			return false
	return is_equal_approx(p.stars, Attributes.stars_of(p.rating10())) and is_equal_approx(p.pot_stars, Attributes.stars_of(p.potential10()))

func _new_players() -> void:
	var c := Career.new_game("CULA", "A", "B", 91)
	var bad := 0
	var flat := 0
	var n := 0
	var mid := 0
	for id in c.teams:
		for p: PoloPlayer in c.teams[id].roster:
			n += 1
			if not _valid(p):
				bad += 1
			if p.rating10() > 8.0:
				continue   # (near 10, the average leaves no room to differ)
			mid += 1
			var lo := 10.0
			var hi := 0.0
			for k in p.key_ratings():
				lo = minf(lo, p.attr(k))
				hi = maxf(hi, p.attr(k))
			if hi - lo < 0.5:
				flat += 1
	r.check(bad == 0, "every school's seven: four attributes, ceilings, stars from them (%d players)" % n)
	r.check(flat < mid / 8, "players have strengths and weaknesses, not four equal numbers (%d of %d flat)" % [flat, mid])
	# the seed keeps every school's original OVR (its first seven generated to it)
	var cula: PoloTeam = c.teams["CULA"]
	r.check(cula.base_ovr() == 91, "CULA's seven still make 91 (%d)" % cula.base_ovr())
	var centres := []
	var wings := []
	for id in c.teams:
		for p: PoloPlayer in c.teams[id].roster:
			if p.pos == PoloPlayer.Pos.CENTER:
				centres.append(p.attr("str") - p.rating10())
			elif p.pos == PoloPlayer.Pos.DEFENDER:
				wings.append(p.attr("dfn") - p.rating10())
	r.check(_mean(centres) > 0.5 and _mean(wings) > 0.5, "centres lean on Strength, centre-defenders on Defense (+%.1f, +%.1f)" % [_mean(centres), _mean(wings)])
	var recruits_bad := 0
	var made: Array = []
	for _i in 200:
		made.append(Recruiting.new_recruit(c))
	for rr in made:
		if not _valid(rr.p):
			recruits_bad += 1
	r.check(recruits_bad == 0, "recruits: valid attributes and ceilings (%d)" % made.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var w := CollegeGen.make_walkon(rng, PoloPlayer.Pos.GK, {})
	r.check(_valid(w) and w.attrs.has("blk"), "a walk-on keeper gets keeper attributes")

func _mean(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s / maxf(1.0, a.size())

func _upgrades() -> void:
	var c := Career.new_game("GWU", "A", "B", 101)
	var p: PoloPlayer = c.team().starters()[3]
	p.tokens = 50
	p.attrs["sho"] = 5.0
	p.attr_pot["sho"] = 7.5
	Attributes.sync(p)
	var bought := 0
	for _i in 6:
		if c.boost(p, "sho"):
			bought += 1
	r.check(bought == 3 and is_equal_approx(p.attr("sho"), Attributes.ceiling(p, "sho")), "upgrades: +1, +1, then the half point left, then AT CEILING (%d bought)" % bought)
	r.check(c.boost_limit(p, "sho") in ["CEILING", "MAXED"], "...and no more past it")
	var others := 0
	for k in p.key_ratings():
		if k != "sho":
			Attributes.set_ceiling(p, k, minf(Attributes.MAX, p.attr(k) + 1.0))   # (room for one each, whatever he was made with)
	p.tokens = 50   # (XP Development 2.0: tokens past his room are dropped, so hand them out again)
	for k in p.key_ratings():
		if k != "sho" and Development.can_spend(p, k):
			while c.boost(p, k):
				others += 1
	r.check(others >= 3 and p.tokens == 0, "no count limit: as many as the ceilings allow; unusable tokens dropped (%d more)" % others)
	r.check(is_equal_approx(p.rating10(), p.potential10()), "bought up to his POTENTIAL")

func _saves() -> void:
	var c := Career.new_game("STAM", "A", "B", 111)
	var text := JSON.stringify(c.to_dict())
	var c2 := Career.from_dict(JSON.parse_string(text))
	var same := true
	for id in c.teams:
		for i in c.teams[id].roster.size():
			var a: PoloPlayer = c.teams[id].roster[i]
			var b: PoloPlayer = c2.teams[id].roster[i]
			same = same and a.attrs == b.attrs and a.attr_pot == b.attr_pot and a.stars == b.stars and a.pot_stars == b.pot_stars
	r.check(same, "attributes and ceilings save and load exactly")
	r.check(JSON.stringify(c2.to_dict()) == text, "a 2.0 save round-trips exactly")

## A save from before 2.0: every player's attributes taken out. They come back from his saved
## stars, exactly the same OVERALL and POTENTIAL, the same every time, and they're kept.
func _old_saves() -> void:
	var c := Career.new_game("SJCU", "A", "B", 121)
	for _w in 2:
		while c.has_game():
			c.sim_my_game()
		c.queue.clear()
		c.end_week()
	var d := c.to_dict()
	var stars := {}
	var halves := [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
	var k := 0
	for id in d.teams:
		for pd in d.teams[id].roster:
			pd.erase("attrs")
			pd.erase("attr_pot")
			pd.erase("stars_locked")
			# an old save's stars were whole halves
			pd.stars = halves[k % 6 + 1]
			pd.pot_stars = maxf(pd.stars, halves[(k + 3) % 9])
			k += 1
			stars[int(pd.id)] = [float(pd.stars), float(pd.pot_stars), int(pd.pos)]
	var text := JSON.stringify(d)
	var a := Career.from_dict(JSON.parse_string(text))
	var b := Career.from_dict(JSON.parse_string(text))
	var kept := true
	var valid := true
	var again := true
	for id in a.teams:
		for i in a.teams[id].roster.size():
			var p: PoloPlayer = a.teams[id].roster[i]
			var s: Array = stars[p.id]
			kept = kept and is_equal_approx(p.stars, Attributes.stars_of(s[0] * 2.0)) and is_equal_approx(p.pot_stars, Attributes.stars_of(s[1] * 2.0)) \
				and absf(p.rating10() - s[0] * 2.0) < 1e-4 and absf(p.potential10() - s[1] * 2.0) < 1e-4
			valid = valid and _valid(p)
			var q: PoloPlayer = b.teams[id].roster[i]
			again = again and p.attrs == q.attrs and p.attr_pot == q.attr_pot
	r.check(kept, "an older save's players keep their OVERALL and POTENTIAL exactly (stars re-read on the new steps)")
	r.check(valid, "...converted into four attributes and ceilings (keepers the keeper four)")
	r.check(again, "...the same every time it's loaded (no dice)")
	var saved := JSON.stringify(a.to_dict())
	var c3 := Career.from_dict(JSON.parse_string(saved))
	r.check(JSON.stringify(c3.to_dict()) == saved and saved.contains("\"attr_pot\""), "...and kept in the save from then on (loading again changes nothing)")
	var forms := true
	for id in a.teams:
		for i in a.teams[id].roster.size():
			forms = forms and (a.teams[id].roster[i] as PoloPlayer).form == (c.teams[id].roster[i] as PoloPlayer).form
	var total := 0.0
	for q: PoloPlayer in a.team().starters():
		total += q.stars
	r.check(forms and a.team().base_ovr() == PoloTeam.display_ovr(34.5 + 13.0 * total / 7.0), "form comes through unchanged, and the team overall is recalculated from the seven as converted")

# ------------------------------------------------------------------ screens
func _screens() -> void:
	var c := Career.new_game("GWU", "A", "B", 131)
	Game.career = c
	var text := JSON.stringify(c.to_dict())
	Game.settings.dev_mode = true
	Game.goto("attr_lab")
	await r.get_tree().process_frame
	var lab = Game.current_screen
	r.check(Game.current_name == "attr_lab" and lab.lab != null and lab.lines.size() > 10, "the ATTRIBUTE TEST LAB opens, with its read-out")
	lab.nudge("pas", 3.0)
	lab.nudge("pas", 1.0, true)
	r.check(is_equal_approx(lab.lab.attr("pas"), 8.0) and is_equal_approx(lab.lab.rating10(), 5.75), "moving an attribute recalculates OVERALL at once (5.75)")
	lab.set_kind(true)
	r.check(lab.lab.is_keeper() and lab.lines.any(func(l): return String(l[0]).begins_with("BLOCKING")), "...and the keeper's four")
	lab.set_form(PlayerForm.VERY_HOT)
	await r.get_tree().process_frame
	r.check(JSON.stringify(c.to_dict()) == text, "nothing in the lab touches the career")
	Game.goto("player", {"id": (c.team().starters()[2] as PoloPlayer).id})
	await r.get_tree().process_frame
	await r.get_tree().process_frame
	var ups := _find(Game.current_screen, "Up_")
	r.check(ups == 4, "the player page: four attributes, each with its upgrade (%d)" % ups)
	Game.goto("player", {"id": (c.team().starters()[0] as PoloPlayer).id})
	await r.get_tree().process_frame
	r.check(_find(Game.current_screen, "Up_blk") == 1, "a keeper's page shows BLOCKING and the other keeper attributes")
	Game.settings.dev_mode = false

func _find(n: Node, prefix: String) -> int:
	var k := 1 if String(n.name).begins_with(prefix) else 0
	for ch in n.get_children():
		k += _find(ch, prefix)
	return k
