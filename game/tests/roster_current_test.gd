extends RefCounted
## The Roster Star Display Cleanup: a Roster screen card shows only the player's CURRENT stars
## (half stars kept, HOT red kept), no hollow POTENTIAL places and no MAX. Every other screen
## (Recruiting's cards, the postgame HOT reveal, his page) keeps its own rules.
##   godot --headless --path game -- --test roster_current
## The pixel checks need a window (drop --headless).

const ROSTER := preload("res://src/ui/screens/roster.gd")
const RV := preload("res://tests/roster_visual_test.gd")

var r
var rv

func run(runner) -> void:
	r = runner
	rv = RV.new()
	print("roster current stars")
	Store.reset_for_tests()
	var c := Career.new_game("LIUB", "Roster", "Current", 11)
	Game.career = c
	var team := c.team()
	for q: PoloPlayer in team.roster:
		q.heat = 0
		q.tokens = 0
		if q.is_injured():
			Development.heal(q)
	# bare stars: only the lit columns of a place
	var fx := StarFx.new()
	fx.bare = true
	r.check(fx._to({"gold": 1.0, "form": 1.0}, 9) == 9 and fx._to({"gold": 0.5, "form": 0.5}, 9) == 5 and fx._to({"gold": 0.0, "form": 0.0}, 9) == 0,
		"bare: a whole star, its left half, nothing")
	r.check(fx._to({"gold": 0.0, "form": 1.0}, 9) == 9, "bare: a red HOT star is still drawn whole")
	fx.bare = false
	r.check(fx._to({"gold": 0.5, "form": 0.5}, 9) == 9, "not bare (every other screen): the whole place, hollow and all")
	fx.free()
	# only the Roster screen asks for it
	var src := FileAccess.get_file_as_string("res://src/ui/screens/roster.gd")
	r.check(src.contains("paint_card(ci, p, team(), fx, shown_form(p), edge, bench, false, true, scout_team != null)"), "the Roster screen's cards: current stars only (the scouted team's too)")
	var rec := FileAccess.get_file_as_string("res://src/ui/screens/recruiting.gd")
	var hot := FileAccess.get_file_as_string("res://src/ui/hot_reveal.gd")
	r.check(rec.contains("paint_card(ci, p, c.team(), fx, PlayerForm.NORMAL, edge, false, true)\n") and hot.contains("paint_card(ci, p, team, fx, state, YELLOW)\n"),
		"Recruiting and the HOT reveal keep their stars as they were")
	r.check(Deck.star_fills(3.0, 5.0).size() == 5 and Deck.star_count(3.5, 4.5) == 5, "the shared star rule (other screens) unchanged: 3 / 5 is five places")
	# a starter, the keeper and a sub fully developed: no MAX anywhere on the board
	var seven := team.starters()
	var subs := team.roster.filter(func(q): return not seven.has(q))
	var maxed: Array = [seven[0], seven[3], subs[0] if not subs.is_empty() else seven[5]]
	for q: PoloPlayer in maxed:
		_max_out(q)
	r.check(maxed.all(func(q): return Development.is_maxed(q)), "three players at their ceiling (keeper, starter, sub)")
	var before := _values(team)
	Game.goto("roster")
	await _frames(runner, 2)
	var scr = Game.current_screen
	UI.drawn_log = []
	for id in scr.cards:
		scr.cards[id].get_child(0).queue_redraw()
	await _frames(runner, 3)
	var log: Array = UI.drawn_log
	UI.drawn_log = null
	r.check(not log.is_empty() and not log.has("MAX"), "no MAX on any roster card (%d strings drawn)" % log.size())
	r.check(log.has(maxed[0].short_name()) and log.has(maxed[2].short_name()), "the maxed players' cards still drawn normally")
	r.check(_values(team) == before, "no rating, potential, XP or token touched by the roster screen")
	if DisplayServer.get_name() == "headless":
		print("  (the pixel checks need a window: --test roster_current without --headless)")
	else:
		await _pixels(runner, scr, team)
	Game.career = null
	Game.goto("title")
	await runner.get_tree().process_frame

## Every card: gold up to CURRENT, then only the panel; then a 3 / 4 player developing to 3.5 and 4.
func _pixels(runner, scr, team: PoloTeam) -> void:
	RV._close_overlays()
	await _frames(runner, 2)
	var img: Image = await rv._shot(runner)
	var bad: Array = []
	for i in PoloTeam.LINEUP_SPOTS.size():
		var q: PoloPlayer = scr.at(i)
		if q == null:
			continue
		var bench := i >= PoloTeam.STARTERS
		var panel := ROSTER.SUB_INFO if bench else ROSTER.GK_INFO if q.is_keeper() else ROSTER.INFO_BG
		if not _only_current(img, scr.cards[q.id].get_global_rect(), q.stars, panel):
			bad.append("%s %.1f/%.1f" % [q.short_name(), q.stars, q.pot_stars])
	r.check(bad.is_empty(), "starters, keeper and subs: current stars only, no hollow places (%s)" % ", ".join(bad))
	# development: 3 / 4 -> 3.5 -> 4, never a grey star, never MAX
	var probe: PoloPlayer = scr.at(PoloTeam.LINEUP_SPOTS.find("cf"))
	var was := [probe.stars, probe.pot_stars]
	var card: Control = scr.cards[probe.id]
	var cr := card.get_global_rect()
	probe.pot_stars = 4.0
	var ok := {}
	for s in [3.0, 3.5, 4.0]:
		probe.stars = s
		card.queue_redraw()
		img = await rv._shot(runner)
		ok[s] = _only_current(img, cr, s, ROSTER.INFO_BG)
	r.check(ok[3.0] and ok[3.5] and ok[4.0], "3 / 4 grows to 3.5 then 4: the card follows, nothing past his current stars (%s)" % str(ok))
	# a half star at its ceiling (3.5 / 3.5) and one under it (3.5 / 4.5) look the same
	probe.stars = 3.5
	probe.pot_stars = 3.5
	card.queue_redraw()
	var a: Image = (await rv._shot(runner)).get_region(Rect2i(Vector2i(cr.position), Vector2i(ROSTER.CARD)))
	probe.pot_stars = 4.5
	card.queue_redraw()
	var b: Image = (await rv._shot(runner)).get_region(Rect2i(Vector2i(cr.position), Vector2i(ROSTER.CARD)))
	r.check(a.get_data() == b.get_data(), "potential has no effect on the card (3.5 / 3.5 == 3.5 / 4.5)")
	# HOT still shows its red star straight after the gold
	probe.stars = 3.0
	probe.heat = 1
	card.queue_redraw()
	img = await rv._shot(runner)
	var red := true
	var at := Vector2i(int(cr.position.x + ROSTER.STAR_X + Deck.star_x(3)), int(cr.position.y + ROSTER.STAR_Y))
	for k: Vector2i in RV._cells(Deck.STAR_INNER):
		red = red and RV._near(img.get_pixelv(at + k), PlayerForm.FIRE_RED)
	r.check(red, "HOT: 3 stars and a red fourth, as before")
	probe.heat = 0
	probe.stars = was[0]
	probe.pot_stars = was[1]
	card.queue_redraw()
	await _frames(runner, 1)

## Places up to CURRENT drawn as the shared star (a half star's left half), every place after it
## only the card's panel.
func _only_current(img: Image, cr: Rect2, cur: float, panel: Color) -> bool:
	var c := PlayerForm.snap_half(cur)
	for i in Deck.STAR_PLACES:
		var fill := clampf(c - i, 0.0, 1.0)
		fill = 1.0 if fill >= 0.99 else (0.5 if fill >= 0.49 else 0.0)
		if not rv._star_at(img, cr, i, fill, panel, true):
			return false
	return true

static func _max_out(q: PoloPlayer) -> void:
	var guard := 0
	while Development.has_room(q) and guard < 200:
		q.tokens += 1
		Development.spend(q, Development.ai_choice(q))
		guard += 1
	q.tokens = 0
	q.xp = 0

static func _values(team: PoloTeam) -> Array:
	var out: Array = []
	for q: PoloPlayer in team.roster:
		out.append([q.id, q.stars, q.pot_stars, q.xp, q.tokens, q.xp_level, q.attrs.duplicate(true)])
	return out

func _frames(runner, n: int) -> void:
	for i in n:
		await runner.get_tree().process_frame
