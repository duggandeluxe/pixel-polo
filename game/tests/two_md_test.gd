extends RefCounted
## The 2MD Defensive Positioning Buff: the man in the 2MD place has his Defense count
## Attributes.TWO_MD_POSITIONING (20%) more in his positioning, and only there.
##   godot --headless --path game -- --test two_md

var r   # the test runner (check)

func run(runner) -> void:
	r = runner
	print("two_md: who gets it")
	_who()
	print("two_md: positioning sums")
	_sums()
	print("two_md: nothing else moves")
	_untouched()

## Exactly one defender is the 2MD, and he's the man in the defending team's 2MD place.
func _who() -> void:
	var p: Play = r._center_play(4401, true)
	var theirs := PlaySetup.seven(p.them)
	var md: Array = p.defenders.filter(func(d: Swimmer): return d.two_md)
	r.check(md.size() == 1 and md[0].player == theirs[PlaySetup.TWO_MD_PLACE],
		"the one 2MD flagged is the man in the 2MD place (%d flagged)" % md.size())
	r.check(p.attackers.all(func(a: Swimmer): return not a.two_md), "no attacker is flagged")
	r.check(PoloTeam.SLOTS[PlaySetup.TWO_MD_PLACE] == PoloTeam.Slot.TWO_MD, "TWO_MD_PLACE is PoloTeam's 2MD slot")
	# a utility put in the 2MD place gets it the same way
	var ut := PoloPlayer.new()
	ut.pos = PoloPlayer.Pos.UTILITY
	r.check(PoloTeam.fits(ut, PlaySetup.TWO_MD_PLACE), "a utility can be put at 2MD (and is flagged by his place, not his position)")

## Each positioning sum: 20% more of the Defense term at 2MD, scaling with his rating (a DEV
## Recruit's past 10 too), every result still in its own bounds.
func _sums() -> void:
	var p: Play = r._center_play(4402, true)
	var c := PlaySetup._by_tag(p, "C")
	var g: Swimmer = p._marker(c)
	var comm := p.comm()
	for dv in [3.0, 5.0, 8.0, 10.0, 13.0]:
		_set_dfn(g.player, dv)
		g.two_md = false
		var e0 := PlayAI.win_edge(p, c, g)
		var w0 := PlayAI.center_switch_wait(g, comm)
		var s0 := PlayAI.seal_mult(p, c, g)
		g.two_md = true
		var e1 := PlayAI.win_edge(p, c, g)
		var w1 := PlayAI.center_switch_wait(g, comm)
		var s1 := PlayAI.seal_mult(p, c, g)
		var eff := Attributes.eff_defense(g.player, comm)
		var want_e := e0 - 0.5 * 0.2 * (eff - 5.0) * Attributes.CENTER_WIN_PER_POINT
		r.check(absf(e1 - want_e) < 0.0001, "D%.0f (eff %.2f): the 2 m hold's Defense term 20%% bigger (%.3f -> %.3f)" % [dv, eff, e0, e1])
		r.check(w1 <= w0 + 0.0001 and w1 > 0.5, "D%.0f: switches sides no later at 2MD, never instantly (%.2f -> %.2f s)" % [dv, w0, w1])
		r.check(s1 <= s0 + 0.0001 and s1 >= 0.7, "D%.0f: back round no later at 2MD, in bounds (%.3f -> %.3f)" % [dv, s0, s1])
		var t1 := PlayAI._win_time(p, c, g)
		r.check(t1 >= PlayAI.CENTER_WIN.x and t1 <= PlayAI.CENTER_WIN.y, "D%.0f: the centre still wins inside water in 5-10 s (%.2f)" % [dv, t1])
	# better Defense, bigger gain
	_set_dfn(g.player, 6.0)
	g.two_md = false
	var lo0 := PlayAI.center_switch_wait(g, comm)
	g.two_md = true
	var lo1 := PlayAI.center_switch_wait(g, comm)
	_set_dfn(g.player, 10.0)
	g.two_md = false
	var hi0 := PlayAI.center_switch_wait(g, comm)
	g.two_md = true
	var hi1 := PlayAI.center_switch_wait(g, comm)
	r.check(hi0 - hi1 > lo0 - lo1, "the better defender gains more (6: %.3f s, 10: %.3f s)" % [lo0 - lo1, hi0 - hi1])
	g.two_md = false
	r.check(is_equal_approx(PlayAI.pos_def(g), 1.0) and PlayAI.pos_def(null) == 1.0, "nobody else's positioning changes")

## His Defense set to `v` (a DEV Recruit's, past 10).
static func _set_dfn(p: PoloPlayer, v: float) -> void:
	p.dev_recruit = "blake" if v > Attributes.MAX else ""
	p.trait_id = ""
	Attributes.set_ceiling(p, "dfn", maxf(v, Attributes.ceiling(p, "dfn")))
	Attributes.set_value(p, "dfn", v)

## Steals, fouls, the pull through, his shown Defense: the same either way.
func _untouched() -> void:
	var p: Play = r._center_play(4403, true)
	var c := PlaySetup._by_tag(p, "C")
	var g: Swimmer = p._marker(c)
	var shown := g.player.attr("dfn")
	var stars := g.player.overall()
	g.two_md = false
	var a := [CenterDefense.steal_chance(p, g, c), CenterDefense.fail_foul(p, g, c), CenterDefense.through_chance(g, c), g.top_speed, Attributes.eff_defense(g.player, p.comm())]
	g.two_md = true
	var b := [CenterDefense.steal_chance(p, g, c), CenterDefense.fail_foul(p, g, c), CenterDefense.through_chance(g, c), g.top_speed, Attributes.eff_defense(g.player, p.comm())]
	r.check(a == b, "steals, missed-challenge fouls, the pull through, speed and effective Defense unchanged")
	r.check(g.player.attr("dfn") == shown and g.player.overall() == stars, "his shown Defense and overall unchanged")
