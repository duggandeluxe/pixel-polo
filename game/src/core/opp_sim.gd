class_name OppSim
## An opponent's possession from ratings alone, for games that aren't played out (GameSim)
## and the shootout's penalty takers. In your own games their attacks are live (PlayDefense).

## Where shots come from, for your goal at x = 0: [commentary, spot, spread] (the keeper tests).
const SPOTS := [
	["FROM THE POINT", Vector2(6.0, 10.0), 1.0],
	["ON THE DRIVE", Vector2(3.0, 10.0), 2.5],
	["FROM THE CENTER", Vector2(2.2, 10.0), 1.0],
	["FROM THE WING", Vector2(3.6, 10.0), 5.5],
	["FROM OUTSIDE", Vector2(7.5, 10.0), 3.5],
	["OFF A CROSS PASS", Vector2(4.2, 10.0), 4.5],
]

## Scoring chance of one opposing possession. Real water polo: roughly 30-40%.
static func goal_chance(attack: float, defense: float, keeping: float) -> float:
	return clampf(0.34 + (attack - defense) * 0.006 - (keeping - 60.0) * 0.004, 0.14, 0.62)

static func _pick_shooter(t: PoloTeam, rng: RandomNumberGenerator) -> PoloPlayer:
	var field := t.starters().slice(1)
	var total := 0.0
	for p: PoloPlayer in field:
		total += pow(p.shoot, 2.0)
	var roll := rng.randf() * total
	for p: PoloPlayer in field:
		roll -= pow(p.shoot, 2.0)
		if roll <= 0.0:
			return p
	return field[0]
