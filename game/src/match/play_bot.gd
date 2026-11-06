class_name PlayBot
## A simple attacker brain: shoots from close or when the clock is low (only ever inside 6 m),
## otherwise looks for an open teammate nearer the goal. Plays the tests and the title-screen demo.

const THINK_EVERY := 0.25

const CALL_CHANCE := 0.15   # per think while he waits: call a drive, as you would
const PRESSED_SHOT := 0.15  # per think with a defender in his face and the goal in range

## Returns {} (wait) or {"target": Vector2, "power": float}. While it waits it sometimes
## calls a DRIVE, like a player would. `pressed`: a defender is right on him, so he moves the
## ball on if anyone's open.
static func think(p: Play, rng: RandomNumberGenerator, pressed: bool = false) -> Dictionary:
	if not p.can_throw():
		return {}
	var h := p.holder
	var goal := Geo.goal_center()
	var dist := h.pos.distance_to(goal)
	var far_y := Geo.GOAL_Y + (1.15 if p.keeper.pos.y < Geo.GOAL_Y else -1.15)
	var shot := {"target": Vector2(Geo.GOAL_X + 0.4, far_y), "power": rng.randf_range(0.65, 0.9)}
	var inside_free := p.shot_barred()
	if p.kind == Play.Kind.PENALTY:
		return shot
	var clear := not p.lane_blocked(shot.target)
	if not clear:
		# a hand in the way of the far post: try the near one
		var near := Vector2(Geo.GOAL_X + 0.4, Geo.GOAL_Y + (Geo.GOAL_Y - far_y) * 0.7)
		if not p.lane_blocked(near):
			shot.target = near
			clear = true
	# the centre with a dropper coming at him (DefenseFormation.center_time): a shot now, or out
	var hurry := h.tag == "C" and DefenseFormation.center_time(p, h) < OffenseAI.CENTER_HURRY
	if hurry and not inside_free and clear and Geo.in_shot_range(h.pos):
		return shot
	# never from outside 6 m (Geo.in_shot_range), not even with the shot clock running out
	if not inside_free and Geo.in_shot_range(h.pos) and (clear or p.shot_clock < 2.5):
		if dist < 4.0 and p.openness(h) > 0.9:
			return shot
		if dist < 7.0 and (p.openness(h) > 1.3 or p.shot_clock < 5.0) and rng.randf() < 0.5:
			return shot
		if p.shot_clock < 2.5:
			return shot
		if pressed and dist < 7.5 and rng.randf() < PRESSED_SHOT:
			return shot   # over the top of the man in his face
	var best: Swimmer = null
	var best_score := -INF
	for a in p.attackers:
		if a == h:
			continue
		var open := p.openness(a)
		var lead := a.pos + a.vel * 0.3
		if p.pass_risk(lead, a) != null:
			continue
		if open < (0.7 if pressed else 1.2) and a.tag != "C":
			continue
		if a.tag == "C" and p.entry_closing(a):
			continue
		var score := open - a.pos.distance_to(goal) * 0.35 + rng.randf() * 0.5
		if a.tag == "C" and DefenseFormation.entry_covered(p, a):
			score -= 1.5   # a man in front of him as well as behind: not through there
		elif a.tag == "C":
			match p.center_entry(h.pos, a):
				"open", "":
					score += 1.2   # feeding the centre from the open side draws exclusions
				"straight":
					score += 0.3
		if a.player.trait_id in ["cannon", "ice"] and a.pos.distance_to(goal) < 8.0:
			score += 0.4   # get it to the shooter
		if score > best_score:
			best_score = score
			best = a
	var patience := 0.35 if p.shot_clock > 12.0 else 0.8
	if pressed or hurry:
		patience = 1.0
	if not Geo.in_shot_range(h.pos):
		patience = maxf(patience, 0.6)   # out of range: he has to move it on to get a shot
	if best != null and (rng.randf() < patience or inside_free):
		return {"target": best.pos + best.vel * 0.3, "power": 0.5}
	if rng.randf() < CALL_CHANCE:
		var sides := CallStrip.SIDES.filter(func(sd): return p.drive_candidate(sd) != null)
		if not sides.is_empty():
			p.call_drive(sides[rng.randi() % sides.size()])
	return {}
