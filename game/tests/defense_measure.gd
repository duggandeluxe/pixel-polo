extends RefCounted
## The numbers behind the Intelligent Defensive AI update, on bot-played matches (both attacks the
## bots', your keeper the bot): goals a possession each way, and (where the game has them: DropCall)
## how often their defence calls its drop, what it decides at halftime and why. Runs on older
## copies too (only what they have), for a before/after.
##   godot --headless --path game -- --test defense_ai_balance [matches]

const DT := 1.0 / 30.0

static func report(runner, matches: int, both := false) -> void:
	var ai: GDScript = load("res://src/match/play_ai.gd")
	if both and ai.get("press_tight") != null:
		for tight in [true, false]:
			ai.set("press_tight", tight)
			print("PlayAI.press_tight = %s (read back %s)" % [tight, ai.get("press_tight")])
			_report(matches)
		ai.set("press_tight", true)
	else:
		_report(matches)

static func _report(matches: int) -> void:
	var spots := [{"centre": 0, "perimeter": 0, "other": 0}, {"centre": 0, "perimeter": 0, "other": 0}]
	var excl := [0, 0]
	var half := {"n": 0, "poss": 0, "drop_poss": 0, "drop_goals": 0, "c_threats": 0, "c_excl": 0, "c_g": 0, "c_sv": 0, "drop_entries": 0, "c_dmg": 0.0, "p_dmg": 0.0}
	var tot := {"att_poss": 0, "att_goals": 0, "def_poss": 0, "def_goals": 0, "dropped": 0, "c_pos": 0, "changes": 0,
		"high_goals": 0, "high_shots": 0, "drop_secs": 0.0}
	var reasons := {}
	var logs := {"c_threats": 0, "c_excl": 0, "goals": 0, "poss": 0}
	var picks := {}
	for i in matches:
		var f = MatchFlow.new(League.make_team(i % 8, 0), League.make_team((i + 3) % 8, 0), 9300 + i, MatchState.QUARTER_MIN)
		var newer: bool = "their_half" in f
		if newer:
			picks[f.get("their_first_drop")] = int(picks.get(f.get("their_first_drop"), 0)) + 1
		var steps := 0
		while f.phase != MatchFlow.Phase.FINAL and steps < 200000:
			steps += 1
			match f.phase:
				MatchFlow.Phase.SPRINT:
					f.sprint_done(f.rng.randf() < 0.5)
				MatchFlow.Phase.ATTACK:
					var p = f.play
					var counted: bool = p.kind != Play.Kind.PENALTY and not f.state.in_shootout
					var before: int = int(f.state.score[0])
					var think := 0.0
					var t := 0.0
					var saw_drop := false
					while not p.over and t < 90.0:
						think -= DT
						if think <= 0.0:
							think = PlayBot.THINK_EVERY
							var d: Dictionary = PlayBot.think(p, f.rng)
							if not d.is_empty():
								p.throw(d.target, d.power)
						f.tick_attack(DT)
						t += DT
						saw_drop = saw_drop or p.formation != DefenseFormation.F.PRESS
						for e in f.events:
							if String(e.k) == "c_position":
								tot.c_pos += 1
						f.events.clear()
					if counted:
						tot.att_poss += 1
						tot.dropped += 1 if saw_drop else 0
						if newer:
							tot.drop_secs += float(p.get("drop_t"))
							var ls: Dictionary = p.get("last_shot")
							if not ls.is_empty() and float(ls.height) > ShotModel.HEIGHT_PEAK:
								tot.high_shots += 1
					f.attack_done()
					if counted:
						var scored: int = int(f.state.score[0]) - before
						tot.att_goals += scored
						if newer and scored > 0 and not (p.get("last_shot") as Dictionary).is_empty() and float(p.get("last_shot").height) > ShotModel.HEIGHT_PEAK:
							tot.high_goals += 1
				MatchFlow.Phase.DEFENSE:
					var counted: bool = f.play.kind != Play.Kind.PENALTY and not f.state.in_shootout
					var before: int = int(f.state.score[1])
					f.auto_keeper = 0.5
					var t := 0.0
					while not f.play.over and t < 90.0:
						f.tick_defense(DT)
						t += DT
					f.events.clear()
					f.defense_done()
					if counted:
						tot.def_poss += 1
						tot.def_goals += int(f.state.score[1]) - before
				MatchFlow.Phase.SHOOTOUT_THEM:
					f.their_ball_done()
				MatchFlow.Phase.THEIR_SHOT:
					f.auto_duel(0.5)
					f.duel_done()
				MatchFlow.Phase.BREAK:
					f.break_done()
		for side in 2:
			for k in spots[side]:
				spots[side][k] += int(f.goal_spots[side][k])
			excl[side] += int(f.state.exclusions[side])
		if newer and not (f.get("their_half") as Dictionary).is_empty():
			var lg: Dictionary = f.get("their_log")
			var c: Dictionary = lg.by.get("C", {})
			half.n += 1
			half.poss += int(lg.poss)
			for k in ["c_threats", "c_excl", "drop_entries", "drop_poss", "drop_goals"]:
				half[k] += int(lg[k])
			half.c_g += int(c.get("g", 0))
			half.c_sv += int(c.get("sv", 0))
			var dc: GDScript = load("res://src/match/drop_call.gd")
			half.c_dmg += float(dc.call("center_damage", lg))
			for t in ["1", "2", "3", "4", "5"]:
				half.p_dmg += float(dc.call("spot_damage", lg, t)) / 5.0
			var h: Dictionary = f.get("their_half")
			tot.changes += 0 if bool(h.keep) else 1
			reasons[String(h.reason)] = int(reasons.get(String(h.reason), 0)) + 1
	var n := float(matches)
	print("DEFENSIVE AI over %d bot matches" % matches)
	print("  your attack (against their defence): %.3f goals a possession (%d of %d), %.2f a game" % [
		float(tot.att_goals) / maxf(1.0, tot.att_poss), tot.att_goals, tot.att_poss, tot.att_goals / n])
	print("  their attack (against yours):         %.3f goals a possession (%d of %d), %.2f a game" % [
		float(tot.def_goals) / maxf(1.0, tot.def_poss), tot.def_goals, tot.def_poss, tot.def_goals / n])
	print("  goals by where the scorer was: yours %s, theirs %s; exclusions drawn a game: yours %.2f, theirs %.2f" % [
		str(spots[0]), str(spots[1]), excl[0] / n, excl[1] / n])
	if int(half.n) > 0:
		var hn := float(half.n)
		print("  ...in a drop: %.2f entries and %.2f goals a drop possession" % [half.drop_entries / maxf(1.0, half.drop_poss), half.drop_goals / maxf(1.0, half.drop_poss)])
		print("  their first halves (mean): %.1f possessions, centre position %.1f, centre exclusions %.1f, centre goals %.1f saves %.1f, entries through the drop %.1f; centre damage %.3f a possession, a perimeter spot's %.3f" % [
			half.poss / hn, half.c_threats / hn, half.c_excl / hn, half.c_g / hn, half.c_sv / hn, half.drop_entries / hn, half.c_dmg / hn, half.p_dmg / hn])
	if not picks.is_empty():
		print("  their first-half drops: %s" % str(picks))
		print("  drop called in %d of %d possessions (%.1f%%), centre position won %d times; %.1f s in a drop a possession on average" % [
			tot.dropped, tot.att_poss, 100.0 * tot.dropped / maxf(1.0, tot.att_poss), tot.c_pos, tot.drop_secs / maxf(1.0, tot.att_poss)])
		print("  halftime: changed %d of %d; reasons %s" % [tot.changes, matches, str(reasons)])
		print("  high shots (last of a possession): %d, of them goals %d" % [tot.high_shots, tot.high_goals])
