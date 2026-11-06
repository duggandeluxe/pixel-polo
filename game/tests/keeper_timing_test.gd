extends RefCounted
## In-game star tags, the goalkeeper's timed dive and the shot's height:
##   godot --headless --path game -- --test keeper_timing
##   godot --headless --path game -- --test shot_height [n]   (only the low / high measurement)
## The tag: stars instead of the OVR number, halves, HOT stars red, nothing else lost. The dive:
## early dives fall before the ball, late ones are still rising, a timed one saves; LEG STRENGTH
## the window, LUNGE SPEED the reaction, BLOCKING the hold; repeated taps never keep him up; the
## recovery; their keeper's dive timed the same way in real possessions. The shot's height: low
## ones a little more often in, high ones a little less, at the same pace, and the keeper's
## position still deciding most of it.

var r

## Goal rates by height third (ShotModel, their keeper) measured on the game as it was before the
## height balance (the same `measure` on a copy whose ShotModel only reported its old reach roll as
## `height`, the same seeds): low (bottom third), middle, high (top third). And your keeper's duel
## (the bot at 0.7) with KeeperDuel.HEIGHT_REACH flat (1, 1): height not counting, as before.
const BASE_AI := Vector3(0.250, 0.196, 0.154)
const BASE_DUEL := Vector3(0.403, 0.394, 0.387)

func run(runner) -> void:
	r = runner
	print("in-game star tag")
	_tag()
	print("keeper dive timing")
	_early_late_timed()
	_legs()
	_lunge()
	_blocking()
	_taps()
	_recovery()
	_live_wind_up()
	_ai_keeper()
	print("shot height")
	_height()

# ------------------------------------------------------------------ the tag
## A keeper, #1 FARRELL, all four attributes at `v` (8.5: five stars, 6.2: three and a half).
func _gk(v: float, heat: int = 0) -> PoloPlayer:
	var p := AttrBench.player({"com": v, "lun": v, "blk": v, "leg": v}, true)
	p.last = "Farrell"
	p.number = 1
	p.heat = heat
	return p

func _tag() -> void:
	var src := FileAccess.get_file_as_string("res://src/match/hud.gd")
	var body := src.get_slice("static func holder_tag", 1).get_slice("## Under the GOAL callout", 0)
	r.check(not body.contains("OVR") and not body.contains("ovr_text") and not body.contains("rating10"), "the tag shows no OVR number")
	var five := _gk(8.5)
	var t := Hud.tag_parts(five)
	r.check(String(t.text).contains("#1") and String(t.text).to_upper().contains("FARRELL") and String(t.text).contains("GK"),
		"name, number and position kept (%s)" % t.text)
	r.check(is_equal_approx(float(t.stars), 5.0) and int(t.red) == 0, "five stars, gold (%.1f)" % float(t.stars))
	var fills := Deck.star_fills(t.stars, t.stars, t.red)
	r.check(fills.all(func(f): return is_equal_approx(float(f.gold), 1.0)), "...five full gold stars")
	var half := _gk(6.2)
	var th := Hud.tag_parts(half)
	var hf := Deck.star_fills(th.stars, th.stars, th.red)
	r.check(is_equal_approx(float(th.stars), half.stars) and fmod(half.stars, 1.0) == 0.5 and is_equal_approx(float(hf[3].gold), 0.5) and hf.size() == 4,
		"half stars: %.1f is three and a half (place 4 half gold)" % half.stars)
	for heat in [1, 2]:
		var hot := _gk(8.5, heat)
		var tt := Hud.tag_parts(hot)
		var ff := Deck.star_fills(tt.stars, tt.stars, tt.red)
		var gold := 0
		var red := 0
		for f in ff:
			if float(f.gold) >= 0.99:
				gold += 1
			elif float(f.form) >= 0.99 and Color(f.form_col) == PlayerForm.FIRE_RED:
				red += 1
		r.check(int(tt.red) == PlayerForm.red_stars(hot.form_state()) and gold == 5 - heat and red == heat,
			"%s: %d gold + %d red, as on his roster card" % [hot.form_state(), gold, red])
		r.check(is_equal_approx(hot.stars, five.stars) and is_equal_approx(hot.pot_stars, five.pot_stars), "...his CURRENT and POTENTIAL untouched")
	five.trait_id = "wall"
	var tw := Hud.tag_parts(five)
	r.check(String(tw.trait) != "" and float(tw.trait_x) >= float(tw.stars_x) + Deck.star_bar_w_for(five.stars, five.stars) + 4.0, "the trait still follows, clear of the stars")
	# (the Roster Restoration stars are 9 px: the tag is its text, the star bar and the trait, no more)
	var parts_w := UI.text_width(String(tw.text), 8, "caps") + Deck.star_bar_w_for(five.stars, five.stars) + 16.0 + UI.text_width(String(tw.trait), 8, "caps") + 6.0
	r.check(float(tw.size.x) <= parts_w + 2.0 and float(tw.size.y) == 12.0, "compact: text, stars and trait only (%.0f px vs %.0f)" % [float(tw.size.x), parts_w])

# ------------------------------------------------------------------ the dive
func _keeper(attrs: Dictionary) -> PoloPlayer:
	return AttrBench.player(attrs, true)

## A duel against a shot crossing `cross` (pool y) after `flight` game seconds, your keeper in the middle.
func _duel(k: PoloPlayer, cross: float, flight: float = 0.5, height: float = 0.5) -> KeeperDuel:
	return KeeperDuel.new().setup_given(k, Vector2(24.0, Geo.GOAL_Y), cross, flight, 0.0, Geo.GOAL_Y, 0.0, height)

## Dive `side` when the ball is `lead` on-screen seconds from the line, then play it out.
func _dive_at(d: KeeperDuel, side: int, lead: float) -> KeeperDuel:
	while d.t < d.flight - lead * d.slowmo and not d.done():
		d.step(0.0025)
	d.dive(side)
	while not d.done():
		d.step(0.0025)
	return d

## The share of `n` shots at the bottom corner, dived for `lead` s ahead, that he keeps out.
func _rate(k: PoloPlayer, lead: float, n: int = 60, cross_off: float = 0.0) -> float:
	var saved := 0
	for i in n:
		var d := _duel(k, Geo.GOAL_Y + 1.0 + cross_off)
		d.rng.seed = 900 + i
		if _dive_at(d, KeeperDive.RIGHT, lead).saved():
			saved += 1
	return float(saved) / n

func _early_late_timed() -> void:
	var k := _keeper({})
	var early := _duel(k, Geo.GOAL_Y + 1.0, 0.6)
	_dive_at(early, KeeperDive.RIGHT, 0.6 / early.slowmo)   # on the release: 1.1 s before it gets there
	r.check(early.outcome == "goal" and early.timing() == "early", "an early dive the right way: fallen back before it arrives, in (TOO EARLY)")
	r.check(early.anim.phase() in [KeeperDive.Phase.RECOVER, KeeperDive.Phase.READY], "...he's back in the water when it gets there")
	var late := _dive_at(_duel(k, Geo.GOAL_Y + 1.0), KeeperDive.RIGHT, 0.04)
	r.check(late.outcome == "goal" and late.timing() == "late", "a late dive: still reacting as it goes past, in (TOO LATE)")
	var timed := _rate(k, _duel(k, Geo.GOAL_Y + 1.0).ideal_up(0.4))
	var too_soon := _rate(k, 0.9)
	var too_late := _rate(k, 0.08)
	print("  bottom corner, average keeper: timed %.2f saved, early %.2f, late %.2f" % [timed, too_soon, too_late])
	r.check(timed >= 0.85, "a timed dive the right way saves it (%.2f)" % timed)
	r.check(too_soon < 0.1 and too_late < 0.35, "early ones expire, late ones mostly beaten (%.2f / %.2f)" % [too_soon, too_late])
	var wrong := _dive_at(_duel(k, Geo.GOAL_Y + 1.0), KeeperDive.LEFT, _duel(k, Geo.GOAL_Y).ideal_up(0.4))
	r.check(wrong.outcome == "goal" and wrong.timing() == "", "perfect timing the wrong way: in (and it isn't called a timing miss)")

## The on-screen leads (s before it arrives, 10 ms apart) a dive for the corner still saves at.
func _saving_span(k: PoloPlayer) -> float:
	var span := 0
	for i in 100:
		var d := _duel(k, Geo.GOAL_Y + 1.0)
		d.block = 1.0   # (his hands aside: only whether he's there in time)
		if _dive_at(d, KeeperDive.RIGHT, 0.02 + i * 0.01).saved():
			span += 1
	return span * 0.01

func _legs() -> void:
	var table := {1: Vector2(0.16, 0.22), 2: Vector2(0.20, 0.24), 3: Vector2(0.24, 0.28), 4: Vector2(0.28, 0.32), 5: Vector2(0.32, 0.36),
		6: Vector2(0.36, 0.40), 7: Vector2(0.40, 0.44), 8: Vector2(0.44, 0.48), 9: Vector2(0.48, 0.52), 10: Vector2(0.50, 0.54)}
	var ok := true
	var prev := 0.0
	var line := "  window by LEG STRENGTH:"
	for g in table:
		var w := Attributes.dive_window(_keeper({"leg": g}))
		line += " %d:%.2f" % [g, w]
		ok = ok and w >= table[g].x - 1e-4 and w <= table[g].y + 1e-4 and w > prev
		prev = w
	print(line)
	r.check(ok, "LEG STRENGTH sets the window, every point counts (3: ~0.26 s, 9: ~0.50 s)")
	var weak := _keeper({"leg": 3})
	var strong := _keeper({"leg": 9})
	var w3 := _duel(weak, Geo.GOAL_Y)._new_dive(KeeperDive.RIGHT)
	var w9 := _duel(strong, Geo.GOAL_Y)._new_dive(KeeperDive.RIGHT)
	r.check(is_equal_approx(w9.fall_at() - w3.fall_at(), w9.window - w3.window)
		and is_equal_approx(w9.extend_time(), w3.extend_time()), "strong legs keep him up longer, they don't get him up sooner")
	var s3 := _saving_span(weak)
	var s9 := _saving_span(strong)
	print("  timing that still saves the corner: legs 3 %.2f s, legs 9 %.2f s" % [s3, s9])
	r.check(s9 > s3 + 0.15, "a strong-legged keeper's timing is more forgiving (%.2f vs %.2f s)" % [s9, s3])
	r.check(s9 < 0.8, "...but even he has to time it (%.2f s of 1 s)" % s9)

func _lunge() -> void:
	var fast := _duel(_keeper({"lun": 10}), Geo.GOAL_Y)._new_dive(KeeperDive.RIGHT)
	var mid := _duel(_keeper({}), Geo.GOAL_Y)._new_dive(KeeperDive.RIGHT)
	var slow := _duel(_keeper({"lun": 0}), Geo.GOAL_Y)._new_dive(KeeperDive.RIGHT)
	print("  full stretch after: lunge 10 %.3f s, 5 %.3f s, 0 %.3f s" % [fast.extend_time(), mid.extend_time(), slow.extend_time()])
	r.check(fast.react_time() < mid.react_time() and mid.react_time() < slow.react_time()
		and fast.extend_time() < mid.extend_time() and mid.extend_time() < slow.extend_time(), "LUNGE SPEED: a quicker reaction and rise")
	r.check(is_equal_approx(fast.window, slow.window), "...not a longer window")
	var lf := 0.0
	var ls := 0.0
	for lead in [0.07, 0.09, 0.11]:
		lf += _rate(_keeper({"lun": 10}), lead, 40) / 3.0
		ls += _rate(_keeper({"lun": 0}), lead, 40) / 3.0
	print("  a late dive (0.07 - 0.11 s ahead): lunge 10 saves %.2f, lunge 0 %.2f" % [lf, ls])
	r.check(lf > ls + 0.3, "a late dive is more forgiving with quick feet")

func _blocking() -> void:
	var lead := _duel(_keeper({}), Geo.GOAL_Y).ideal_up(0.4)
	var dv := AttrBench.dive(_keeper({}))
	var tip := float(dv.lunge) + float(dv.reach) * 0.92 - 1.0   # (from the corner at 1.0 m: 92% of the way out to his fingertips)
	var good := _rate(_keeper({"blk": 10}), lead, 200, tip)
	var poor := _rate(_keeper({"blk": 0}), lead, 200, tip)
	print("  timed, at his fingertips: blocking 10 holds %.2f, blocking 0 %.2f" % [good, poor])
	r.check(good > poor + 0.05, "BLOCKING still decides the ones he gets to")

func _taps() -> void:
	var k := _keeper({})
	var d := _duel(k, Geo.GOAL_Y - 1.0, 1.4)   # a long one: 2.5 s on screen
	var dives := 0
	var last: KeeperDive = null
	var up := 0.0
	var longest := 0.0
	var restarted := false
	while not d.done():
		var before := d.anim
		var t_before := d.anim.t if d.anim != null else -1.0
		d.dive(KeeperDive.LEFT if dives % 2 == 0 else KeeperDive.RIGHT)   # tapping every frame, both ways
		if d.anim != before:
			dives += 1
		elif d.anim != null and d.anim.t < t_before:
			restarted = true
		d.step(0.01 * d.slowmo)
		if d.anim != null and d.anim.active():
			up += 0.01
			longest = maxf(longest, up)
		else:
			up = 0.0
		last = d.anim
	var cycle := last.down_at() + KeeperDive.RECOVERY
	print("  tapping every frame for %.1f s: %d dives, longest up %.2f s (window %.2f)" % [d.flight / d.slowmo, dives, longest, last.window])
	r.check(not restarted and longest <= last.window + 0.011, "taps never restart a dive or keep him up past his window")
	r.check(dives <= ceili(d.flight / d.slowmo / cycle) + 1, "a new dive only once he's recovered (%d in %.1f s)" % [dives, d.flight / d.slowmo])

func _recovery() -> void:
	r.check(KeeperDive.RECOVERY >= 0.15 and KeeperDive.RECOVERY <= 0.30, "recovery %.2f s (0.15 .. 0.30)" % KeeperDive.RECOVERY)
	var d := _duel(_keeper({}), Geo.GOAL_Y + 1.0, 1.5)
	d.dive(KeeperDive.RIGHT)
	var a := d.anim
	var seen := {}
	var can := {}
	while not a.done():
		d.step(0.005 * d.slowmo)
		seen[a.phase()] = true
		can[a.phase()] = d.can_dive()
	r.check(seen.has(KeeperDive.Phase.FALL) and seen.has(KeeperDive.Phase.RECOVER), "every dive falls, then recovers")
	r.check(not can.get(KeeperDive.Phase.ACTIVE, true) and not can.get(KeeperDive.Phase.FALL, true) and not can.get(KeeperDive.Phase.RECOVER, true),
		"no new dive while he's up, falling or recovering")
	r.check(d.can_dive(), "...and he can go again once he's back")
	d.dive(KeeperDive.LEFT)
	r.check(d.anim != a and d.anim.side == KeeperDive.LEFT, "a second dive, the other way")

## Live defence: a dive during their wind-up runs its course; if it's over before the shot, the
## shot has to beat a keeper back in the water.
func _live_wind_up() -> void:
	var teams := [League.make_team(2, 1), League.make_team(3, 1)]
	var f := MatchFlow.new(teams[0], teams[1], 77, MatchState.QUARTER_MIN)
	f._start_defense(Play.Kind.HALF_COURT)
	r.check(not f.can_dive(), "no dive with nothing on (he tracks the ball)")
	f.opp_plan = {"target": Vector2(Geo.GOAL_X, Geo.GOAL_Y + 1.0), "power": 0.8, "shot": true, "t": 5.0}
	r.check(f.can_dive(), "their shooter winding up: you can go")
	f.dive_side(KeeperDive.RIGHT)
	var a := f.keeper_anim
	r.check(a != null and f.play.keeper.pose == a, "the guess plays out on screen")
	f.dive_side(KeeperDive.LEFT)
	r.check(f.keeper_anim == a and a.side == KeeperDive.RIGHT, "...one dive, locked")
	for i in 30:
		f._steer_keeper(1.0 / 60.0)
	f._open_duel({"from": Vector2(25.0, 10.0), "cross_y": Geo.GOAL_Y + 1.0, "flight": 0.5, "keeper_y": Geo.GOAL_Y, "n": 1, "height": 0.5})
	r.check(f.duel.anim == a and f.keeper_anim == null and f.duel.tapped, "the shot comes while he's still in it: that dive has to stop it")
	while not f.duel.done():
		f.duel.step(1.0 / 60.0 * f.duel.slowmo)
	r.check(f.duel.outcome == "goal" and f.duel.timing() == "early", "he went too soon: fallen when it arrives, in")

## Their keeper (ShotModel decides, Play draws): his dive has the same four phases, timed so the
## ball gets to him while he's up, and it always ends.
func _ai_keeper() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var pairings := [[League.make_team(2, 1), League.make_team(3, 1)], [League.make_team(1, 2), League.make_team(4, 2)]]
	var saves := 0
	var up_saves := 0
	var poses := 0
	var stuck := false
	var longest := 0.0
	for i in 160:
		var teams: Array = pairings[i % pairings.size()]
		var p := Play.new(teams[0], teams[1], Play.Kind.PENALTY if i % 5 == 0 else Play.Kind.HALF_COURT, rng)
		var t := 0.0
		var think := 0.0
		var dt := 1.0 / 60.0
		var held := 0.0
		var pose: KeeperDive = null
		while not p.over and t < 60.0:
			think -= dt
			if think <= 0.0:
				think = PlayBot.THINK_EVERY
				var dd := PlayBot.think(p, rng)
				if not dd.is_empty():
					p.throw(dd.target, dd.power)
			var flying := p.ball.state == Ball.State.SHOT
			var sh: Dictionary = p.ball.shot if flying else {}
			p.step(dt)
			if p.keeper.pose != null:
				if p.keeper.pose != pose:
					poses += 1
					pose = p.keeper.pose
					held = 0.0
				if pose.active():
					held += dt
					longest = maxf(longest, held)
			if flying and p.ball.state != Ball.State.SHOT and String(sh.get("outcome", "")) in ["save", "parry"]:
				saves += 1
				if pose != null and pose.phase() in [KeeperDive.Phase.RISE, KeeperDive.Phase.ACTIVE]:
					up_saves += 1
			t += dt
		var after := 0.0
		while p.keeper.pose != null and after < 3.0:
			p.keeper.pose.advance(dt)
			if p.keeper.pose.done():
				p.keeper.pose = null
			after += dt
		stuck = stuck or p.keeper.pose != null
	print("  their keeper: %d dives drawn, %d saves (%d with him up), longest up %.2f s" % [poses, saves, up_saves, longest])
	r.check(poses > 20 and saves > 10, "their keeper dives and saves in real possessions")
	r.check(up_saves >= saves * 0.9, "his saves come while he's up (%d of %d)" % [up_saves, saves])
	r.check(not stuck and longest <= Attributes.WINDOW_RANGE.y + 0.02, "his dives fall back too: never up past his window")
	# the same pace whatever the keeper: ShotModel's reaction and reach (AI difficulty) don't read the window
	var fast := ShotModel.resolve(Vector2(24.0, 8.0), 11.0, 0.8, 60.0, 4.0, [], Geo.GOAL_Y, 60.0, _seeded(5))
	var again := ShotModel.resolve(Vector2(24.0, 8.0), 11.0, 0.8, 60.0, 4.0, [], Geo.GOAL_Y, 60.0, _seeded(5))
	r.check(fast.outcome == again.outcome and fast.reaction == again.reaction, "their keeper's save is ShotModel's, as it was (deterministic)")

func _seeded(s: int) -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = s
	return g

# ------------------------------------------------------------------ the shot's height
## Goal rates by height third: [ShotModel low, mid, high], [duel low, mid, high], from `n` shots.
static func measure(n: int = 24000) -> Dictionary:
	var spots := [Vector2(24.0, 10.0), Vector2(25.5, 7.5), Vector2(25.5, 12.5), Vector2(23.0, 9.0), Vector2(27.0, 13.5), Vector2(22.0, 11.0)]
	var aims := [Geo.GOAL_Y - 1.1, Geo.GOAL_Y + 1.1, Geo.GOAL_Y - 0.6, Geo.GOAL_Y + 0.6, Geo.GOAL_Y]
	var ai := [[0, 0], [0, 0], [0, 0]]
	var rng := RandomNumberGenerator.new()
	for i in n:
		rng.seed = 5000 + i
		var res := ShotModel.resolve(spots[i % spots.size()], aims[(i / spots.size()) % aims.size()], 0.8, 60.0, 4.0, [], Geo.GOAL_Y, 60.0, rng)
		if not res.has("height") or String(res.outcome) in ["miss", "post", "block"]:
			continue
		var b := mini(int(float(res.height) * 3.0), 2)
		ai[b][1] += 1
		if String(res.outcome) == "goal":
			ai[b][0] += 1
	var shooter := AttrBench.player({})
	var gk := AttrBench.player({}, true)
	var duel := [[0, 0], [0, 0], [0, 0]]
	var drng := RandomNumberGenerator.new()
	drng.seed = 77
	var brng := RandomNumberGenerator.new()
	brng.seed = 78
	for i in n / 4:
		var from: Vector2 = OppSim.SPOTS[i % OppSim.SPOTS.size()][1] + Vector2(0, drng.randf_range(-2.0, 2.0))
		var d := KeeperDuel.new().setup(shooter, gk, from, 0.0, drng, 0.0)
		var o := d.auto(0.7, brng)
		if not d.on_target:
			continue
		var h = d.get("height")
		var b := mini(int(float(h if h != null else 0.5) * 3.0), 2)
		duel[b][1] += 1
		if o == "goal":
			duel[b][0] += 1
	var rate := func(c: Array) -> float: return float(c[0]) / maxf(1.0, float(c[1]))
	var all_duel := float(duel[0][0] + duel[1][0] + duel[2][0]) / maxf(1.0, float(duel[0][1] + duel[1][1] + duel[2][1]))
	return {"ai": [rate.call(ai[0]), rate.call(ai[1]), rate.call(ai[2])], "duel": [rate.call(duel[0]), rate.call(duel[1]), rate.call(duel[2])],
		"duel_all": all_duel}

func _height() -> void:
	var m := measure()
	var ai: Array = m.ai
	var du: Array = m.duel
	print("  their keeper, goals by height: low %.3f  mid %.3f  high %.3f  (before: %.3f %.3f %.3f)" % [ai[0], ai[1], ai[2], BASE_AI.x, BASE_AI.y, BASE_AI.z])
	print("  your keeper (bot 0.7):         low %.3f  mid %.3f  high %.3f  (height flat: %.3f %.3f %.3f)" % [du[0], du[1], du[2], BASE_DUEL.x, BASE_DUEL.y, BASE_DUEL.z])
	# (BASE_AI was their keeper reading the flight, before the AI overhaul: he guesses now, so
	# more go in at every height. The height still counts the same way: low over high)
	# low ones are a stretch down, shoulder height is his best, the top corner is his legs' (ShotModel.height_reach)
	r.check(ShotModel.height_reach(0.0) < ShotModel.height_reach(ShotModel.HEIGHT_PEAK) and ShotModel.height_reach(1.0, 0.1) < ShotModel.height_reach(1.0, 0.9)
		and ShotModel.height_reach(1.0, 0.1) < ShotModel.height_reach(ShotModel.HEIGHT_PEAK), "their keeper: low shots and (weak legs) the top corner are harder to reach than shoulder height")
	r.check(float(ai[0]) > float(ai[1]), "...low ones go in more often than shoulder height")
	r.check(float(ai[0]) - float(ai[2]) < 0.15, "...a little: where he went decides most of it")
	r.check(float(du[0]) / BASE_DUEL.x >= 1.02 and float(du[0]) / BASE_DUEL.x <= 1.14 and float(du[2]) / BASE_DUEL.z >= 0.86
		and float(du[2]) / BASE_DUEL.z <= 0.98, "in your goal too: low ones a little harder to stop (x%.2f), high ones a little easier (x%.2f)"
		% [float(du[0]) / BASE_DUEL.x, float(du[2]) / BASE_DUEL.z])
	r.check(float(ai[0]) < 0.9, "a low shot is no sure thing")
	# the same pace whatever the height: speed is fixed before the height is rolled
	var speeds := {}
	var heights := {}
	for s in 60:
		var res := ShotModel.resolve(Vector2(24.0, 9.0), Geo.GOAL_Y + 1.0, 0.8, 60.0, 4.0, [], Geo.GOAL_Y, 60.0, _seeded(s))
		speeds[snappedf(float(res.speed), 0.0001)] = true
		if res.has("height"):
			heights[mini(int(float(res.height) * 3.0), 2)] = true
	r.check(speeds.size() == 1 and heights.size() == 3, "low, middle or high, the same shot flies at the same speed")
	var flights := {}
	for s in 40:
		var d := KeeperDuel.new().setup_given(_keeper({}), Vector2(24.0, 9.0), Geo.GOAL_Y + 1.0, 0.45, 0.0, Geo.GOAL_Y, 0.0, s / 39.0)
		flights[d.flight] = true
	r.check(flights.size() == 1, "...and in your goal")
	# the keeper's position still decides it: the same low shots, him there or not
	var there := 0
	var away := 0
	for s in 400:
		var a := ShotModel.resolve(Vector2(24.0, 10.0), Geo.GOAL_Y + 1.1, 0.8, 60.0, 4.0, [], Geo.GOAL_Y, 60.0, _seeded(s), false, {}, {"dive_side": 1})
		var b := ShotModel.resolve(Vector2(24.0, 10.0), Geo.GOAL_Y + 1.1, 0.8, 60.0, 4.0, [], Geo.GOAL_Y, 60.0, _seeded(s), false, {}, {"dive_side": -1})
		if float(a.get("height", 1.0)) < 0.34:
			there += 1 if String(a.outcome) == "goal" else 0
			away += 1 if String(b.outcome) == "goal" else 0
	r.check(away > there * 2, "a low shot at a keeper who went that way is mostly saved; the other way, mostly in (%d vs %d)" % [there, away])
