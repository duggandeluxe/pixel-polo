extends "res://src/ui/screens/roster.gd"
## SCOUT OPPONENT (from Coaching): your next unplayed game's opponent (Career.next_game), read
## fresh every time it opens, so it's always the team you play next as it is today. It's the
## Roster screen, read only (roster.gd's scouting: his seven in their places, his bench, the same
## cards, his team in the places beside his keeper); a card opens his page in scouting mode
## (player.gd: his current stars and attributes, statistics and Career Accolades, nothing of his
## potential, nothing to edit), and back from there comes here. Looking changes nothing: no
## ratings, lineups, AI, credits or points, and your gameplan stays as it was.

func scouted() -> PoloTeam:
	return next_opponent(Game.career)

func _ready() -> void:
	if next_opponent(Game.career) != null:
		super()
		return
	back_target = "coaching"
	build_compact("SCOUT OPPONENT")
	var v := UI.vbox(4)
	var p := navy_panel(v)
	p.name = "NoOpponent"
	v.add_child(big_text("NO UPCOMING OPPONENT", UI.ACCENT))
	v.add_child(para("There's no game left on your schedule to scout%s." % (
		": the next round hasn't been drawn yet" if c.next_game().get("tbd", false) else ""), UI.TEXT, 300))
	body.add_child(UI.spacer(0, 2))
	body.add_child(p)
	body.add_child(UI.spacer(0, 0, true))

## The team you play next (your next unplayed game), or null: no game left this season, or a
## playoff round still to be drawn.
static func next_opponent(car: Career) -> PoloTeam:
	if car == null:
		return null
	var g := car.next_game()
	if g.is_empty() or not g.has("opp"):
		return null
	return car.teams.get(String(g.opp))

func on_back() -> void:
	Sfx.play("back")
	Game.goto("coaching")
