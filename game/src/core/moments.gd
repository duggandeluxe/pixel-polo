class_name Moments
## The little dramas of a career between games: which locker-room talk fits the result, the
## Player of the Game and the player who needs a word, the week's event card and the press
## question. Picks only; Career.apply_effects() does what the choices say.

const CARD_CHANCE := 0.35      # an event card at the end of a week

## win, big_win, close_loss, loss, title or out (see LockerData).
static func context(won: bool, margin: int, shootout: bool, round_kind: String) -> String:
	if won and round_kind in ["conf_final", "nat_final"]:
		return "title"
	# only an NCSA loss is certainly the end: a conference-tournament loser can still get an
	# at-large bid
	if not won and round_kind.begins_with("nat_"):
		return "out"
	if won:
		return "big_win" if margin >= 5 else "win"
	return "close_loss" if (margin >= -1 or shootout) else "loss"

## {id: score} for this game's box: goals count double, keepers get credit for saves.
static func game_scores(goals: Array, assists: Array, keeper: PoloPlayer, saves: int) -> Dictionary:
	var out := {}
	for p in goals:
		out[p.id] = int(out.get(p.id, 0)) + 2
	for p in assists:
		out[p.id] = int(out.get(p.id, 0)) + 1
	if keeper != null:
		out[keeper.id] = int(out.get(keeper.id, 0)) + saves / 3
	return out

## "2 GOALS, 1 ASSIST" or "11 SAVES" for the Player of the Game card.
static func stat_line(p: PoloPlayer, goals: Array, assists: Array, keeper: PoloPlayer, saves: int) -> String:
	if p == null:
		return ""
	if p == keeper:
		return "%d SAVES" % saves
	var g := goals.count(p)
	var a := assists.count(p)
	var parts := PackedStringArray()
	if g > 0:
		parts.append("%d GOAL%s" % [g, "" if g == 1 else "S"])
	if a > 0:
		parts.append("%d ASSIST%s" % [a, "" if a == 1 else "S"])
	return ", ".join(parts)

static func mvp(t: PoloTeam, scores: Dictionary) -> PoloPlayer:
	var best: PoloPlayer = null
	var bs := 0
	for p in t.roster:
		var sc := int(scores.get(p.id, 0))
		if sc > bs:
			bs = sc
			best = p
	return best

# ------------------------------------------------------------------ event cards
## A card for this week, or {}: {type: "card", id, pid}.
static func pick_card(c: Career) -> Dictionary:
	if c.rng.randf() >= CARD_CHANCE:
		return {}
	var options: Array = CardsData.CARDS.filter(func(cd): return not (cd.get("once", false) and cd.id in c.cards_seen))
	options.shuffle()
	for cd in options:
		var p := player_for(c, String(cd.get("who", "any")))
		if p != null or cd.get("who", "any") == "any":
			return {"type": "card", "id": cd.id, "pid": p.id if p != null else 0}
	return {}

static func card(id: String) -> Dictionary:
	for cd in CardsData.CARDS:
		if cd.id == id:
			return cd
	return {}

## The player a card is about.
static func player_for(c: Career, who: String) -> PoloPlayer:
	var t := c.team()
	var fit: Array = t.roster.filter(func(p: PoloPlayer): return p.is_available())
	if fit.is_empty():
		return null
	match who:
		"center":
			fit = fit.filter(func(p: PoloPlayer): return p.pos == PoloPlayer.Pos.CENTER)
		"keeper":
			fit = fit.filter(func(p: PoloPlayer): return p.is_keeper())
		"shooter":
			fit = t.starters().slice(1).filter(func(p: PoloPlayer): return p.is_available())
			fit.sort_custom(func(a: PoloPlayer, b: PoloPlayer): return a.shoot > b.shoot)
			fit = fit.slice(0, 3)
		"freshman":
			fit = fit.filter(func(p: PoloPlayer): return p.year == 1)
		"senior":
			fit = fit.filter(func(p: PoloPlayer): return p.year == 4)
	if fit.is_empty():
		return null
	return fit[c.rng.randi() % fit.size()]

## "{name}" -> the player's name, "{NAME}" -> his last name in capitals.
static func fill(text: String, p: PoloPlayer) -> String:
	if p == null:
		return text.replace("{name}", "a player").replace("{NAME}", "HIM")
	return text.replace("{name}", "%s %s" % [p.first, p.last]).replace("{NAME}", p.last.to_upper())