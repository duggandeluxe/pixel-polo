extends RefCounted
## The Dynamic Star Display Cleanup: a player's bar ends at his POTENTIAL (Deck.star_count), no
## empty places to make it five; half stars, red HOT stars and the star art as they were; team
## rows still five.
##   godot --headless --path game -- --test star_display

var r

## A bar as tokens, a place each: G gold, g half gold, R red, o hollow (POTENTIAL), h half hollow.
func _row(cur: float, pot: float, red: int = 0) -> String:
	var out: Array = []
	for f in Deck.star_fills(cur, pot, red):
		var g := float(f.gold)
		if float(f.form) > g and float(f.form) >= 0.99:
			out.append("R")
		elif g >= 0.99:
			out.append("G")
		elif g > 0.0:
			out.append("g")
		elif float(f.pot) >= 0.99:
			out.append("o")
		elif float(f.pot) > 0.0:
			out.append("h")
		else:
			out.append(".")
	return " ".join(out)

func run(runner) -> void:
	r = runner
	print("star display")
	r.check(_row(3.0, 3.0) == "G G G", "1: 3 / 3 is three gold stars (%s)" % _row(3.0, 3.0))
	r.check(_row(2.0, 2.0) == "G G", "2: 2 / 2 is two (%s)" % _row(2.0, 2.0))
	r.check(_row(4.0, 4.0) == "G G G G", "3: 4 / 4 is four")
	r.check(_row(5.0, 5.0) == "G G G G G", "5 / 5 is five")
	r.check(_row(3.0, 5.0) == "G G G o o", "4: 3 / 5 is three gold, two hollow")
	r.check(_row(3.0, 4.5) == "G G G o h", "5: 3 / 4.5 is three gold, one and a half hollow (%s)" % _row(3.0, 4.5))
	r.check(_row(2.5, 2.5) == "G G g" and _row(2.5, 4.0) == "G G g o" and _row(4.0, 4.5) == "G G G G h", "6: half stars, current and potential")
	r.check(_row(4.5, 5.0) == "G G G G g", "4.5 / 5: the last place half gold (its other half the hollow)")
	# no trailing places past POTENTIAL, anywhere
	var clean := true
	for ci in range(1, 11):
		for pi in range(ci, 11):
			var n := Deck.star_fills(ci * 0.5, pi * 0.5).size()
			if n != ceili(pi * 0.5):
				clean = false
	r.check(clean, "7: every CURRENT x POTENTIAL: the bar ends with his POTENTIAL's place")
	# development: reaching the ceiling takes the hollow place away
	var p := PoloPlayer.new()
	p.stars = 3.0
	p.pot_stars = 4.0
	var before := Deck.star_fills(p.stars, p.pot_stars).size()
	p.stars = 4.0
	r.check(before == 4 and _row(p.stars, p.pot_stars) == "G G G G", "8: 3 / 4 grows to 4 / 4: the hollow star goes")
	r.check(is_equal_approx(Deck.star_bar_w_for(3.0, 3.0), 2 * Deck.STAR_STEP + 9.0), "8: no room kept for the missing places")
	# HOT
	r.check(_row(3.0, 3.0, 1) == "G G G R", "9: 3 / 3 HOT: three gold, then his red star")
	r.check(_row(3.0, 4.0, 1) == "G G G R", "9: 3 / 4 HOT: the red star in the place after the gold, as before")
	r.check(_row(5.0, 5.0, 2) == "G G G R R" and _row(4.0, 4.0, 2) == "G G G R R", "9: never past five, the gold giving way as before")
	r.check(StarFx.changed_places(3.0, 3.0, PlayerForm.NORMAL, PlayerForm.HOT) == [3] and StarFx.span(3.0, 3.0, PlayerForm.HOT, PlayerForm.NORMAL) == 4,
		"9: heating up / cooling down animates the red place, then it goes")
	# every player bar uses the one rule; team rows stay five
	var src := ""
	for f in ["src/ui/screens/roster.gd", "src/ui/screens/player.gd", "src/ui/screens/awards.gd", "src/ui/screens/scout.gd",
			"src/ui/screens/roster_cuts.gd", "src/ui/screens/coaching.gd", "src/match/hud.gd"]:
		src += FileAccess.get_file_as_string("res://" + f)
	r.check(not src.contains("Deck.stars(") and not src.contains("star_bar_w()") and not src.contains("star_bar_w(Deck.STAR_SHAPE)"),
		"11: every player bar is the unified bar, its width its own")
	r.check(Deck.star_fills(3.5, float(Deck.STAR_PLACES)).size() == 5 and Deck.star_bar_texture(2.0).get_width() == int(Deck.star_bar_w()),
		"team OFF / DEF / GK rows: still five places")
	r.check(Deck.STAR.size() == 9 and int(Deck.STAR_SHAPE.w) == 9 and int(Deck.STAR_SHAPE.half) == 5 and Deck.STAR_STEP == 10.0, "12: the star art as it was")
	# 10: recruits show what they did before (POTENTIAL is visible to everyone since scouting went);
	# the opponent scout's rows and the awards still show CURRENT only
	var scout := FileAccess.get_file_as_string("res://src/ui/screens/scout.gd")
	r.check(scout.contains("star_bar(ci, 0, 0, q.stars, q.stars, red)"), "10: opponents' bars never show potential")
	# 13: a pure drawing change
	var c := Career.new_game("LIUB", "A", "B", 7)
	var q: PoloPlayer = c.team().roster[1]
	var was := [q.stars, q.pot_stars, q.overall(), c.team().live_ovr()]
	Deck.star_fills(q.stars, q.pot_stars, 2)
	Deck.star_bar_w_for(q.stars, q.pot_stars, 1)
	r.check(was == [q.stars, q.pot_stars, q.overall(), c.team().live_ovr()], "13: no rating touched")
