extends RefCounted
## The Hot Star Gameplay & Scouting Overhaul: the SCOUTING REPORT in place of HOME POOL, Hot
## Stars as +0.5 / +1.0 to all four attributes (past 10, used by the game, never shown or saved),
## the match fire (HotFire) and Developer Mode's HOT STAR TESTING (hot_star_lab).
##   godot --headless --path game -- --test hot_stars
## Screenshots (needs a window): --test hot_stars_png <dir>

const ROSTER := preload("res://src/ui/screens/roster.gd")

var r

func run(runner) -> void:
	r = runner
	print("hot stars")
	Store.reset_for_tests()
	await _scouting()
	_attributes()
	_gameplay()
	_no_double_count()
	_fire()
	await _dev_lab()
	_saves()
	Game.career = null

func _frames(n: int = 2) -> void:
	for i in n:
		await r.get_tree().process_frame

func _node(name: String) -> Node:
	return Game.current_screen.find_child(name, true, false)

func _field(vals: Dictionary, heat: int = 0) -> PoloPlayer:
	var p := AttrBench.player(vals)
	p.heat = heat
	return p

func _keeper(vals: Dictionary, heat: int = 0) -> PoloPlayer:
	var p := AttrBench.player(vals, true)
	p.heat = heat
	return p

# ------------------------------------------------------------------ 1-8 scouting
func _scouting() -> void:
	var c := Career.new_game("GWU", "Hot", "Stars", 41)
	c.queue.clear()
	Game.career = c
	var opp: PoloTeam = load("res://src/ui/screens/scout.gd").next_opponent(c)
	r.check(opp != null, "S0: there's a next opponent to scout")
	Game.goto("scout")
	await _frames(3)
	var rep: Control = _node("ScoutReport")
	r.check(_node("ScoutPool") == null and rep != null, "S1-2: HOME POOL's box is gone, the SCOUTING REPORT is there")
	var meta := String(rep.get_meta("text", "")) if rep != null else ""
	r.check(not meta.contains("HOME POOL") and meta.contains("OFFENSE") and meta.contains("DEFENSE"), "S2-3: OFFENSE and DEFENSE, no pool")
	var src := FileAccess.get_file_as_string("res://src/ui/screens/roster.gd")
	r.check(not src.contains("\"HOME POOL\""), "S1: HOME POOL isn't drawn anywhere on the scouting screen")
	if rep != null:
		r.check(is_equal_approx(float(rep.get_meta("off")), PoloTeam.rating_stars(opp.offense_display()))
			and is_equal_approx(float(rep.get_meta("def")), PoloTeam.rating_stars(opp.defense_display())),
			"S6-7: the stars are the scouted team's real OFFENSE / DEFENSE through rating_stars")
		r.check(src.contains("Deck.star_bar(ci, bx, top + 10, off if i == 0 else dfn, float(Deck.STAR_PLACES))"), "S4: drawn with the game's own five-place star bar")
		# where HOME POOL was, clear of the team box and every card
		var y := ROSTER.LABEL_H + 2.0 * (ROSTER.CARD.y + ROSTER.ROW_GAP)
		r.check(rep.position.is_equal_approx(Vector2(2.0 * (ROSTER.CARD.x + ROSTER.GAP), y)) and rep.size.is_equal_approx(ROSTER.CARD),
			"S8: the panel sits exactly where HOME POOL was, card-sized")
		var mine := rep.get_global_rect().grow(-0.5)
		var clear := true
		for n in Game.current_screen.find_children("*", "Control", true, false):
			var cn := n as Control
			if cn == rep or not cn.visible or cn.is_ancestor_of(rep) or rep.is_ancestor_of(cn):
				continue
			var nm := String(cn.name)
			if nm == "ScoutTeam" or nm.begins_with("Spot_") or nm.begins_with("Bench_") or nm.begins_with("Empty_"):
				clear = clear and not mine.intersects(cn.get_global_rect())
		r.check(clear, "S8: overlaps nothing (the team box, the cards)")
		r.check(Game.current_screen.get_viewport_rect().encloses(rep.get_global_rect()), "S8: on screen, nothing clipped")
	# half stars: the conversion keeps them, the bar draws them
	r.check(is_equal_approx(PoloTeam.rating_stars(73.0), 3.5) and is_equal_approx(PoloTeam.rating_stars(77.0), 4.0), "S5: half stars (73 -> 3.5, 77 -> 4)")
	var fills := Deck.star_fills(3.5, 5.0)
	r.check(fills.size() == 5 and is_equal_approx(float(fills[3].gold), 0.5), "S5: a 3.5 bar is three gold, a half, one hollow")
	# no hollow numbers: the panel's texts are words and stars
	r.check(not meta.contains("OVR") and not meta.contains(str(opp.offense_display())), "S: no numerical OVR in the panel")
	Game.goto("coaching")
	await _frames(2)

# ------------------------------------------------------------------ 9-16, 18-20 attributes
func _attributes() -> void:
	var vals := {"pas": 7.0, "sho": 8.0, "str": 6.0, "dfn": 5.0}
	for heat in 3:
		var p := _field(vals, heat)
		var ok := true
		for k in vals:
			ok = ok and is_equal_approx(Attributes.effective(p, k), float(vals[k]) + 0.5 * heat)
		r.check(ok, "A9-11: %d Hot Star%s: +%.1f to all four field attributes" % [heat, "" if heat == 1 else "s", 0.5 * heat])
	r.check(is_equal_approx(Attributes.hot_bonus(_field(vals, 2)), 1.0), "A12: two Hot Stars are +1.0, never +1.5")
	var kv := {"blk": 8.0, "lun": 9.0, "com": 7.0, "leg": 8.0}
	var gk := _keeper(kv, 2)
	var gk_ok := gk.is_keeper()
	for k in kv:
		gk_ok = gk_ok and is_equal_approx(Attributes.effective(gk, k), float(kv[k]) + 1.0)
	r.check(gk_ok, "A13: a keeper's four get the same (+1.0 with two: LUNGE 9 -> 10)")
	var ten := _field({"pas": 7.0, "sho": 10.0, "str": 8.0, "dfn": 6.0}, 1)
	r.check(is_equal_approx(Attributes.effective(ten, "sho"), 10.5), "A15: SHOOTING 10 + one Hot Star = 10.5")
	ten.heat = 2
	r.check(is_equal_approx(Attributes.effective(ten, "sho"), 11.0), "A14/16: + two = 11.0 (not capped at 10)")
	# permanent attributes never move
	var before := ten.attrs.duplicate()
	var rat := [ten.shoot, ten.passing, ten.strength, ten.defense]
	Attributes.sync(ten)
	r.check(ten.attrs == before and [ten.shoot, ten.passing, ten.strength, ten.defense] == rat and is_equal_approx(Attributes.value(ten, "sho"), 10.0),
		"A18: his saved attributes and 0-100 ratings stay as they are (sync never takes the bonus)")
	var cold := _field(vals, 0)
	r.check(is_equal_approx(Attributes.effective(cold, "sho"), 8.0) and PlayerForm.LEVELS.size() == 3, "A20: no cold form, no bonus: a NORMAL player plays his own")
	# injuries still come off first
	var hurt := _field(vals, 1)
	hurt.inj_type = "shoulder" if Development.INJURIES.has("shoulder") else String(Development.INJURIES.keys()[0])
	hurt.inj_sev = String((Development.INJURIES[hurt.inj_type] as Dictionary).keys()[0])
	var pen := Development.penalties(hurt)
	var k0: String = pen.keys()[0] if not pen.is_empty() else "sho"
	r.check(is_equal_approx(Attributes.effective(hurt, k0), maxf(0.0, float(vals[k0]) - Development.penalty(hurt, k0)) + 0.5), "A: an injury's penalty first, the Hot bonus on top")
	# the form system itself is untouched
	var q := _field(vals, 0)
	for i in 3:
		PlayerForm.push_grade(q, PlayerForm.GOOD)
	r.check(q.heat == 1 and Attributes.hot_stars(q) == 1 and is_equal_approx(Attributes.hot_bonus(q), 0.5), "A20: three GOOD games: HOT, and the bonus follows")
	for i in 5:
		PlayerForm.push_grade(q, PlayerForm.BAD)
	r.check(q.heat == 0 and is_equal_approx(Attributes.hot_bonus(q), 0.0), "A/F31: the stars go, the bonus goes with them")
	# the profile never shows the boosted number
	for path in ["res://src/ui/screens/player.gd", "res://src/ui/screens/roster.gd", "res://src/ui/deck.gd", "res://src/ui/screens/recruiting.gd"]:
		var s := FileAccess.get_file_as_string(path)
		r.check(not s.contains("hot_bonus") and not s.contains("Attributes.effective") and not s.contains("play_value") and not s.contains("HotFire"),
			"A19/F18: %s shows permanent attributes only, no fire" % path.get_file())

# ------------------------------------------------------------------ 17 the game reads them
func _gameplay() -> void:
	var base := {"pas": 7.0, "sho": 10.0, "str": 8.0, "dfn": 10.0}
	var n := _field(base, 0)
	var h := _field(base, 1)
	var v := _field(base, 2)
	r.check(Attributes.shot_pace(n) < Attributes.shot_pace(h) and Attributes.shot_pace(h) < Attributes.shot_pace(v)
		and is_equal_approx(Attributes.shot_pace(v) - Attributes.shot_pace(n), Attributes.PACE_PER_POINT), "G17: SHOOTING: harder shots, a whole point's pace at two stars, even from 10")
	r.check(Attributes.release_mult(v) < Attributes.release_mult(n), "G17: SHOOTING: a quicker release")
	r.check(n.live("shoot") + 8.0 == v.live("shoot") and n.live("shoot") + 4.0 == h.live("shoot"), "G17: SHOOTING: accuracy rating +4 / +8 (live)")
	var pn := Attributes.pass_mod(_field({"pas": 10.0}, 0))
	var pv := Attributes.pass_mod(_field({"pas": 10.0}, 2))
	r.check(pv > pn and is_equal_approx(pv, 0.12), "G17: PASSING: the catch-and-shoot edge past 10 (0.10 -> 0.12)")
	r.check(Attributes.strength(v) > Attributes.strength(n) and is_equal_approx(Attributes.strength(v), 9.0), "G17: STRENGTH: the 2 m battle and the press read 9")
	r.check(Attributes.eff_defense(v, 0.0) > 10.0 and is_equal_approx(Attributes.eff_defense(v, 0.0), 11.0), "G17: DEFENSE: 11 with two stars")
	r.check(is_equal_approx(Attributes.eff_defense(n, 0.5), 10.0), "G: a cold 10 with organising stays at 10, as before")
	var mate := _field({"pas": 5.0}, 0)
	r.check(DefenseFormation.tip_chance(v, mate) >= DefenseFormation.tip_chance(n, mate) and DefenseFormation.move_mult(v) > DefenseFormation.move_mult(n),
		"G17: DEFENSE: tips and his swim on defence")
	var kv := {"blk": 10.0, "lun": 10.0, "com": 10.0, "leg": 10.0}
	var kn := _keeper(kv, 0)
	var kh := _keeper(kv, 2)
	r.check(Attributes.lunge_mult(kh) < Attributes.lunge_mult(kn) and Attributes.leg_reach(kh) > Attributes.leg_reach(kn)
		and Attributes.dive_window(kh) > Attributes.dive_window(kn) and Attributes.block_mod(kh) > Attributes.block_mod(kn)
		and Attributes.comm_bonus(kh) > Attributes.comm_bonus(kn), "G17: KEEPER: lunge, reach, window, blocking, organising, all past 10")
	r.check(Attributes.keeper_skill(kh, "lun") > Attributes.keeper_skill(kn, "lun") and KeeperLegs.cap(kh) < KeeperLegs.cap(kn), "G17: KEEPER: reaction and the legs in a drop")
	# safety limits kept
	var hold := Attributes.hold_chance(1.0, Attributes.block_mod(kh))
	r.check(hold <= 1.0 and Attributes.dive_window(kh) <= Attributes.WINDOW_RANGE.y and Attributes.keeper_skill(kh, "leg") <= 1.0
		and DefenseFormation.tip_chance(v, mate) <= DefenseFormation.TIP_RANGE.y, "G: probabilities and the dive keep their bounds")
	# in a real possession the play reads the same numbers once
	var us := League.make_team(2, 1)
	var them := League.make_team(3, 1)
	var g := MatchFlow.new(us, them, 950, MatchState.QUARTER_MIN)
	g._start_attack(Play.Kind.HALF_COURT)
	var sh: Swimmer = g.play.attackers[1]
	sh.player.heat = 0
	var p0: float = g.play.shot_pace(sh)
	sh.player.heat = 2
	var p2: float = g.play.shot_pace(sh)
	r.check(is_equal_approx(p2, Attributes.shot_pace(sh.player)) and p2 > p0, "G17/21: Play.shot_pace is the attribute pace, Hot Stars in it once")
	var duel := KeeperDuel.new().setup(sh.player, them.starters()[0], Vector2(Geo.GOAL_X - 6.0, Geo.GOAL_Y), Geo.GOAL_X, RandomNumberGenerator.new(), 0.5)
	r.check(is_equal_approx(duel.shooter_pace, clampf(Attributes.shot_pace(sh.player) / 100.0, 0.0, 1.0)) and duel.by == sh.player,
		"G21: their shot's pace in your keeper's duel: the bonus once")
	sh.player.heat = 0

# ------------------------------------------------------------------ 21 team ratings
func _no_double_count() -> void:
	var t := League.make_team(1, 1)
	for p: PoloPlayer in t.roster:
		p.pro = false
		p.heat = 0
	var off := t.offense_display()
	var dfn := t.defense_display()
	var gk := t.goalkeeping_display()
	var ovr := t.team_overall()
	var fd := t.form_delta()
	for p: PoloPlayer in t.starters():
		p.heat = 1
	r.check(t.offense_display() == off and t.defense_display() == dfn and t.goalkeeping_display() == gk,
		"T21: OFFENSE / DEFENSE / GK displays stay on permanent attributes (no bonus in them)")
	r.check(t.team_overall() > ovr and t.form_delta() > fd, "T: the team overall's HEAT UP and the engine's form term still count Hot Stars, as before")
	var sim := FileAccess.get_file_as_string("res://src/core/game_sim.gd") + FileAccess.get_file_as_string("res://src/core/opp_sim.gd")
	r.check(not sim.contains("Attributes.") and not sim.contains("hot_bonus"), "T21: a simulated game takes form only from the team term: never the attribute bonus too")
	var pl := FileAccess.get_file_as_string("res://src/match/play.gd")
	r.check(not pl.contains("RATING_PER_STAR") and not pl.contains("eff_stars"), "T21: the pool never adds a second form term to a shot")

# ------------------------------------------------------------------ 22-37 the fire
func _rects(f: Callable) -> Array:
	HotFire.record = []
	f.call()
	var out: Array = HotFire.record
	HotFire.record = null
	return out

func _top(rs: Array) -> float:
	var y := INF
	for e in rs:
		y = minf(y, (e[0] as Rect2).position.y)
	return y

func _has_col(rs: Array, c: Color) -> bool:
	return rs.any(func(e): return (e[1] as Color).r8 == c.r8 and (e[1] as Color).g8 == c.g8 and (e[1] as Color).b8 == c.b8)

func _fire() -> void:
	var view := PoolView.new()
	view.width = 480.0
	view.height = 270.0
	var s := Swimmer.new(_field({"sho": 8.0}, 0), Swimmer.Side.US)
	s.pos = Vector2(Geo.GOAL_X - 7.0, Geo.GOAL_Y)
	view.zoom_to = 1.0
	view.snap_to(s.pos)
	var man := func(lv: int, t: float, still := false) -> Array:
		s.player.heat = lv
		return _rects(func():
			HotFire.draw_under(null, view, s, t, -1, still)
			HotFire.draw_over(null, view, s, t, -1, still))
	var a0: Array = man.call(0, 1.0)
	var a1: Array = man.call(1, 1.0)
	var a2: Array = man.call(2, 1.0)
	r.check(a0.is_empty(), "R1: no Hot Stars: nothing on the man")
	var one_clear := true
	for t in [0.0, 0.3, 0.77, 1.5, 2.9]:
		one_clear = one_clear and (man.call(1, t) as Array).is_empty()
	r.check(one_clear, "R2-3: one Hot Star: the man as ever, no aura, no sparks, at any moment")
	r.check(not a2.is_empty(), "R6: two Hot Stars: the spark ring")
	# the ring: on the water round him, never up his body
	var c := view.to_screen(s.pos).round() + HotFire.RING_C
	var on_ring := true
	for t in [0.0, 0.1, 0.35, 0.6, 1.2, 2.5]:
		for e in man.call(2, t):
			var d := (e[0] as Rect2).position - c
			on_ring = on_ring and absf(d.x) <= HotFire.RING_R.x + 3.0 and absf(d.y) <= HotFire.RING_R.y + 3.0
	r.check(on_ring, "R7/9: every spark on or just off the ring (no flames round his body)")
	var top := _top(a2)
	r.check(top >= view.to_screen(s.pos).y - 5.0, "R10: nothing higher than his shoulders' waterline")
	var front := _rects(func(): HotFire.draw_over(null, view, s, 1.0, 2, false))
	r.check(front.all(func(e): return (e[0] as Rect2).position.y >= view.to_screen(s.pos).y + 1.0), "R10: what's drawn over him is on the water below his shoulders, never on his sprite")
	var cols_ok := a2.all(func(e): var cc: Color = e[1]; return cc.a == 1.0 and [HotFire.RING_GOLD, HotFire.YELLOW, HotFire.ORANGE, HotFire.CORE].any(func(k): return k.r8 == cc.r8 and k.g8 == cc.g8 and k.b8 == cc.b8))
	r.check(cols_ok and not _has_col(a2, HotFire.RED), "R5: golden sparks, orange flashes, solid colours, no red fire")
	r.check(a2.size() <= 50 and a2.all(func(e): return (e[0] as Rect2).size == Vector2.ONE), "R12/5: a light ring of single pixels")
	# it moves with him
	s.pos += Vector2(2.0, 1.0)
	var moved: Array = man.call(2, 1.0)
	var shift := view.to_screen(s.pos).round() - c + HotFire.RING_C
	var follows := moved.size() == a2.size()
	for i in mini(moved.size(), a2.size()):
		follows = follows and (moved[i][0] as Rect2).position.is_equal_approx((a2[i][0] as Rect2).position + shift)
	r.check(follows, "R11: the ring follows him")
	s.pos -= Vector2(2.0, 1.0)
	# every gameplay state
	var states := {"swimming": func(): s.vel = Vector2(2, 0),
		"holding": func(): s.arm = 0.6,
		"defending": func(): s.side = Swimmer.Side.THEM,
		"keeper": func(): s.keeper = true}
	for k in states:
		(states[k] as Callable).call()
		r.check(not (man.call(2, 2.0) as Array).is_empty() and (man.call(1, 2.0) as Array).is_empty(), "R12/16: ring at two stars, nothing at one, while %s" % k)
	s.keeper = false
	s.side = Swimmer.Side.US
	r.check((man.call(2, 1.0) as Array).size() > 0 and (man.call(0, 1.0) as Array).is_empty(), "R17: it goes the moment the stars do")
	# animated: the runs go round, the sparks come and go
	var differs := false
	for i in 6:
		differs = differs or str(man.call(2, 0.13 * i)) != str(a2)
	r.check(differs, "R5: the ring's sparks move")
	var calm_a: Array = man.call(2, 0.3, true)
	var calm_b: Array = man.call(2, 1.7, true)
	r.check(str(calm_a) == str(calm_b) and not calm_a.is_empty() and calm_a.size() < a2.size() + 4, "R24: Reduce Motion: a still ring, still there")
	r.check(is_equal_approx(Attributes.hot_bonus(s.player), 1.0), "R24: ...and the bonus is the same")
	# crisp pixels
	var whole := true
	for e in a2:
		var rr: Rect2 = e[0]
		whole = whole and rr.position.is_equal_approx(rr.position.round()) and rr.size.is_equal_approx(rr.size.round())
	r.check(whole, "R: whole-pixel rects only")
	# the ball
	var b := Ball.new()
	b.state = Ball.State.SHOT
	b.from = s.pos
	b.to = Vector2(Geo.GOAL_X, Geo.GOAL_Y)
	b.pos = s.pos.lerp(b.to, 0.5)
	b.t = 0.5
	b.dur = 0.5
	b.z = 0.5
	b.shooter = s
	var snap := [b.pos, b.z, b.from, b.to, b.t, b.state, b.shot.duplicate(), s.pos, s.vel]
	var shot := func(lv: int, t := 1.0, still := false) -> Array:
		s.player.heat = lv
		return _rects(func(): HotFire.draw_ball_fire(null, view, b, t, null, -1, still))
	var s0: Array = shot.call(0)
	var s1: Array = shot.call(1)
	var s2: Array = shot.call(2)
	r.check(s0.is_empty(), "R1: no Hot Stars, a plain shot")
	var same := not s1.is_empty()
	for t in [0.0, 0.2, 0.55, 1.0, 1.9]:
		same = same and str(shot.call(1, t)) == str(shot.call(2, t))
	r.check(same, "R4/8: one Hot Star and two: the very same flaming shot, frame for frame")
	# the shot is the first update's VERY HOT one: seven trail blobs, the orange-round-red rim, a tongue
	var rim := s1.any(func(e): return (e[0] as Rect2).size == Vector2(10, 8) and (e[1] as Color).r8 == HotFire.ORANGE.r8) \
		and s1.any(func(e): return (e[0] as Rect2).size == Vector2(8, 6) and (e[1] as Color).r8 == HotFire.RED.r8)
	r.check(rim and _has_col(s1, HotFire.CORE) and _has_col(s1, HotFire.RED) and s1.size() >= 7 + 2 + 2, "R13: the flaming shot as it was (trail, rim, tongue, embers)")
	var shot_still: Array = shot.call(1, 1.0, true)
	r.check(not shot_still.is_empty() and shot_still.size() < s1.size() and str(shot.call(1, 0.4, true)) == str(shot_still), "R24: Reduce Motion: the shot keeps its fire, no flicker or embers")
	# the trail goes back along the flight
	var behind := true
	var dir := (b.to - b.from).normalized()
	var ball_px := view.to_screen(Vector2(b.look().x, b.look().y), b.look().z)
	for e in s1:
		var cc := (e[0] as Rect2).get_center()
		behind = behind and (cc - ball_px).dot(Vector2(dir.x, 0).normalized()) <= 6.0
	r.check(behind, "R14: the fire trails the ball, never ahead of it")
	r.check([b.pos, b.z, b.from, b.to, b.t, b.state, b.shot, s.pos, s.vel] == snap, "R22: drawing it changes nothing on the ball or the man")
	var ms := FileAccess.get_file_as_string("res://src/match/match_screen.gd")
	var i_fire := ms.find("HotFire.draw_ball_fire(ci, view, flow.play.ball")
	var i_ball := ms.find("PoolArt.draw_ball(ci, view, flow.play.ball)")
	r.check(i_fire > 0 and i_ball > i_fire, "R: the ball is drawn over its fire (always seen where it is)")
	var i_ring := ms.find("HotFire.draw_under(ci, view, s, t)")
	var i_body := ms.find("PoolArt.draw_body(ci, view, s, _cap(s), _trim(s), _design(s))")
	var i_front := ms.find("HotFire.draw_over(ci, view, s, t)")
	r.check(i_ring > 0 and i_body > i_ring and i_front > i_body, "R10/15: the ring's back half under every body, its front half after it")
	for path in ["res://src/match/play.gd", "res://src/core/shot_model.gd", "res://src/core/keeper_ai.gd", "res://src/match/keeper_dive.gd", "res://src/match/defense_formation.gd", "res://src/match/shot_stick.gd"]:
		r.check(not FileAccess.get_file_as_string(path).contains("HotFire"), "R22-23: %s never reads the art" % path.get_file())
	# passes and a ball in hand: nothing (only the shot burns)
	b.state = Ball.State.PASS
	b.passer = s
	b.t = 0.1
	s.player.heat = 2
	r.check(_rects(func(): HotFire.draw_ball_fire(null, view, b, 1.0, null, -1, false)).is_empty(), "R: a hot pass has no fire")
	b.state = Ball.State.HELD
	r.check(_rects(func(): HotFire.draw_ball_fire(null, view, b, 1.0, s, -1, false)).is_empty(), "R: the ball in a hot man's hand has no fire")
	# not in menus
	for path in ["res://src/ui/portrait.gd", "res://src/ui/hot_reveal.gd", "res://src/ui/screens/scout.gd", "res://src/ui/screens/trophy_room.gd",
			"res://src/ui/screens/coach_event.gd", "res://src/ui/screens/postgame_review.gd", "res://src/ui/screens/title.gd", "res://src/ui/screens/awards.gd"]:
		r.check(not FileAccess.get_file_as_string(path).contains("HotFire"), "R: no Hot Star art in %s" % path.get_file())
	# light
	var t0 := Time.get_ticks_usec()
	HotFire.record = []
	for i in 140:   # 14 men, VERY HOT, ten frames
		s.player.heat = 2
		HotFire.draw_under(null, view, s, i * 0.016)
		HotFire.draw_over(null, view, s, i * 0.016)
	var count: int = HotFire.record.size()
	HotFire.record = null
	var us := float(Time.get_ticks_usec() - t0)
	r.check(count / 140.0 <= 50.0, "R: about %d pixels a VERY HOT man a frame" % roundi(count / 140.0))
	r.check(us / 10.0 < 4000.0, "R: fourteen VERY HOT men cost %.2f ms a frame" % (us / 10000.0))
	s.player.heat = 0

# ------------------------------------------------------------------ 38-46, 48 Developer Mode
func _dev_lab() -> void:
	var c := Career.new_game("GWU", "Lab", "Test", 43)
	c.queue.clear()
	Game.career = c
	Game.settings.dev_mode = true
	Game.goto("settings")
	await _frames(3)
	var names := ["FormLab", "TempoLab", "AttrLab", "HotLab", "FxLab", "DefenseLab", "RecordLab", "CoachLab", "HotStarLab"]
	var all := names.all(func(n): return _node(n) != null)
	r.check(all, "D38/48: HOT STAR TESTING with every other developer tool")
	var real: PoloPlayer = c.team().starters()[3]
	var real_heat := real.heat
	var real_attrs := real.attrs.duplicate()
	var real_dict := JSON.stringify(c.team().to_dict())
	Game.goto("hot_star_lab")
	await _frames(4)
	var lab = Game.current_screen
	r.check(lab.player() != null and lab.ids.size() == c.team().roster.size(), "D39: the whole roster to pick from")
	var first: PoloPlayer = lab.player()
	r.check(first.is_keeper(), "D39: keeper first")
	lab.select(3)
	await _frames(2)
	var p: PoloPlayer = lab.player()
	r.check(p.id == real.id and p != real, "D39: picking a player: the lab's copy of him")
	lab.set_stars(1)
	var rows: Array = lab.rows()
	var ok := true
	for row: Array in rows:
		var v := String(row[1])
		if v.contains("|"):
			var parts := v.split("|")
			var key := ""
			for k in Attributes.NAMES:
				if String(Attributes.NAMES[k]).to_upper() == String(row[0]):
					key = k
			ok = ok and key != "" and parts[0] == Attributes.text(Attributes.value(p, key)) and parts[1] == Attributes.text(Attributes.value(p, key) - Development.penalty(p, key) + 0.5)
	r.check(ok and rows.size() >= 10, "D40-41: BASE and EFFECTIVE for all four (+0.5 at one star)")
	var text := str(rows)
	r.check(text.contains("SPARK RING") and text.contains("FLAMING SHOT") and text.contains("REDUCE MOTION") and text.contains("+0.5 EACH")
		and not text.contains("AURA"),
		"D26: stars, bonus, spark ring, flaming shot, Reduce Motion")
	for n in 3:
		lab.set_stars(n)
		r.check(Attributes.hot_stars(lab.player()) == n and is_equal_approx(Attributes.effective(lab.player(), "sho") - Development.eff_value(lab.player(), "sho"), 0.5 * n),
			"D42: SET %d HOT STARS" % n)
	for n in 3:
		lab.preview_stars(n)
		await _frames(2)
		var sh: Swimmer = lab.play.ball.shooter
		r.check(lab.play.ball.state == Ball.State.SHOT and sh != null and sh.player == lab.player() and HotFire.level_of(sh) == n,
			"D25: PREVIEW %d HOT STARS: his shot at %d" % [n, n])
	lab.select(3)
	lab.preview_shot()
	await _frames(2)
	r.check(HotFire.level_of(lab.play.ball.shooter) == 1 and lab.play.ball.state == Ball.State.SHOT, "D25: FLAMING SHOT with no stars: at one")
	lab.preview_ring()
	await _frames(2)
	var his: Swimmer = null
	for s in lab.play.bodies():
		if s.player == lab.player():
			his = s
	r.check(his != null and HotFire.level_of(his) == 2 and not lab.paused, "D25: 2-STAR SPARK RING: him in the water at two stars, playing on")
	r.check(_node("PreviewShot") != null and _node("PreviewRing") != null and _node("ResetTest") != null and _node("Preview0") != null
		and _node("Preview2") != null and _node("PreviewAura1") == null and _node("PreviewAura2") == null, "D25: the new previews, the old aura ones gone")
	lab.select(0)
	lab.preview_stars(2)
	await _frames(2)
	r.check(lab.play.keeper.player == lab.player() and HotFire.level_of(lab.play.keeper) == 2 and HotFire.level_of(lab.play.ball.shooter) == 2,
		"D16: a keeper: in goal with his ring, the man on the ball shoots at his stars")
	lab.reset_state()
	r.check(lab.player().heat == c.team().find_id(lab.player().id).heat and not lab.still, "D26: RESET VISUAL PREVIEW: his real stars back")
	lab.select(3)
	lab.set_stars(2)
	lab.apply_to_test_game()
	await _frames(3)
	var ms = Game.current_screen
	var us: PoloTeam = ms.flow.us
	var tp: PoloPlayer = us.find_id(real.id)
	r.check(us != c.team() and tp != null and tp.heat == 2 and not ms.career and Attributes.hot_bonus(tp) == 1.0, "D45: APPLY TO TEST GAME: a real match, the copy at two stars, not a career game")
	Game.goto("settings")
	await _frames(2)
	r.check(real.heat == real_heat and real.attrs == real_attrs and JSON.stringify(c.team().to_dict()) == real_dict, "D46: the real player, team and save never touched")
	Game.settings.dev_mode = false

# ------------------------------------------------------------------ 27, 47 saves
func _saves() -> void:
	var p := _field({"pas": 7.0, "sho": 10.0, "str": 8.0, "dfn": 6.0}, 2)
	var d := p.to_dict()
	r.check(is_equal_approx(float((d.attrs as Dictionary).sho), 10.0) and int(d.heat) == 2 and not JSON.stringify(d).contains("11.0"),
		"V27: the save keeps his ten and his heat, never the 11")
	var back := PoloPlayer.from_dict(JSON.parse_string(JSON.stringify(d)))
	r.check(back.heat == 2 and is_equal_approx(Attributes.effective(back, "sho"), 11.0) and is_equal_approx(Attributes.value(back, "sho"), 10.0),
		"V47: loaded back, the bonus is worked out again from his stars")
	var old := d.duplicate(true)
	old.erase("heat")
	old["form"] = [1, 1, 1]
	var o := PoloPlayer.from_dict(old)
	r.check(o.heat == 1 and is_equal_approx(Attributes.hot_bonus(o), 0.5), "V47: a save from before two-level heat: its HOT plays +0.5")
