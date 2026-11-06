extends RefCounted
## The Home Waters update (every school's own named pool) and the Offensive & Defensive Star
## Ratings update (team OFF/DEF overalls shown as stars).
##   godot --headless --path game -- --test home_waters

var r

const FACILITY := ["Natatorium", "Aquatic Center", "Aquatics Center", "Aquatics Complex", "Pool"]

func run(runner) -> void:
	r = runner
	print("home waters & OFF/DEF stars")
	Store.reset_for_tests()
	_venues()
	await _matchup()
	_stars()
	Game.career = null

func _frames(n: int) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _venues() -> void:
	var names := {}
	for s in Colleges.SCHOOLS:
		var v := Colleges.venue_name(String(s.short))
		names[v] = true
		r.check(v != "" and FACILITY.any(func(f): return v.contains(f)), "2: %s plays at a real facility (%s)" % [s.name, v])
	r.check(Colleges.SCHOOLS.size() == 30 and names.size() == 30, "1: 30 schools, 30 different pools")
	r.check(Colleges.venue_name("LIUB") == "Hammerhead Harbor Natatorium" and Colleges.venue_name("CULA") == "The Bear Den Aquatic Center"
		and Colleges.venue_name("CCSB") == "The Bullring Natatorium" and Colleges.venue_name("ICU") == "The Burrow Aquatic Center", "3: the official names")
	# home, away, neutral; across a save and a new season
	var c := Career.new_game("LIUB", "A", "B", 3)
	var g := c.my_game()
	r.check(c.venue_name() == Colleges.venue_name(String(g.h)), "4-5: the game's venue is the home team's pool (%s)" % c.venue_name())
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(back.venue_name() == c.venue_name(), "8: the same after a save")
	g["nu"] = true
	r.check(c.venue_name() == "", "6: a neutral site keeps its own rule: no home pool named")
	g.erase("nu")
	var later := Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	later.year += 1
	later.start_season()
	r.check(Colleges.venue_name(later.school) == Colleges.venue_name("LIUB"), "8: the same pool next season")

func _matchup() -> void:
	var c := Career.new_game("LIUB", "A", "B", 4)
	c.queue.clear()
	Game.career = c
	for q in c.upgrades_due():
		Development.ai_spend(q)
	Game.goto("matchup")
	await _frames(3)
	var v: Label = Game.current_screen.find_child("Venue", true, false)
	var want := Colleges.venue_name(String(c.my_game().h)).to_upper()
	r.check(v != null and v.text == want, "3-5: the pregame screen names the venue (%s)" % (v.text if v else "none"))
	var bar: Control = Game.current_screen.find_child("VenueBar", true, false)
	var view: Rect2 = Game.current_screen.get_viewport_rect()
	r.check(bar != null and bar.is_ancestor_of(v) and view.encloses(bar.get_global_rect()), "venue bar 1-4: the name in its own navy bar, on screen")
	var longest := ""
	for s in Colleges.SCHOOLS:
		if UI.text_width(String(s.venue).to_upper(), 16, "big") > UI.text_width(longest, 16, "big"):
			longest = String(s.venue).to_upper()
	r.check(UI.text_width(longest, 16, "big") <= 284.0, "9: every pool name fits the bar on one line in the big font (the longest, %s: %.0f px)" % [longest, UI.text_width(longest, 16, "big")])
	var page: ScrollContainer = Game.current_screen.body.get_parent()
	var need := 0.0
	for ch: Control in Game.current_screen.body.get_children():
		need += ch.get_combined_minimum_size().y
	need += 3.0 * maxf(0, Game.current_screen.body.get_child_count() - 1)
	print("  matchup body needs %.0f, page %.0f" % [need, page.size.y])
	if not DisplayServer.get_name() == "headless":
		r.check(need <= page.size.y + 0.5, "the matchup page fits without scrolling (%.0f of %.0f)" % [need, page.size.y])
	for nm in ["Play", "Sim"]:
		var b: Control = Game.current_screen.find_child(nm, true, false)
		r.check(b != null and view.encloses(b.get_global_rect()) and not b.get_global_rect().intersects(bar.get_global_rect()), "venue bar 7-8: %s fully on screen, clear of the bar" % nm)
	# OFF and DEF as stars, never numbers
	var off: Array = Game.current_screen.find_children("StarsOFFENSE", "", true, false)
	var def: Array = Game.current_screen.find_children("StarsDEFENSE", "", true, false)
	r.check(off.size() == 2 and def.size() == 2, "stars 1: both teams' OFFENSE and DEFENSE in stars")
	var home: PoloTeam = c.teams[c.my_game().h]
	r.check(is_equal_approx(float(off[0].get_meta("stars")), PoloTeam.rating_stars(home.offense_display())), "stars 6: from the team's own OFF overall")
	var gk: Array = Game.current_screen.find_children("StarsGOALKEEPING", "", true, false)
	r.check(gk.size() == 2 and is_equal_approx(float(gk[0].get_meta("stars")), PoloTeam.rating_stars(home.goalkeeping_display())), "matchup 1-2: GOALKEEPING in stars too, from the team's own rating")
	var big: Array = Game.current_screen.find_children("Overall", "", true, false)
	r.check(big.size() == 2 and int(big[0].get_meta("overall")) == home.overall_display(), "matchup 5-7: each team's overall, a big number of its own")
	var shown := []
	for lb in Game.current_screen.find_children("*", "Label", true, false):
		shown.append((lb as Label).text)
	r.check(not "RATING" in shown, "matchup 2: the small RATING row is gone")

func _stars() -> void:
	var table := [[40, 2.0], [50, 2.5], [60, 3.0], [70, 3.5], [80, 4.0], [90, 4.5], [99, 5.0], [0, 0.0], [74, 3.5], [86, 4.5]]
	r.check(table.all(func(e): return is_equal_approx(PoloTeam.rating_stars(float(e[0])), float(e[1]))), "stars 4-6: the nearest half star of rating / 20")
	var tex := Deck.star_bar_texture(3.5)
	r.check(tex.get_width() == int(Deck.star_bar_w()) and tex.get_height() == Deck.STAR.size(), "stars 3: the game's own star bar, five places")
	var rich := CreditCoin.rich("OFF %s" % (CreditCoin.STARS % 3.5), 8)
	r.check(rich is RichTextLabel, "stars 2: stars in text are the sprite, not characters")
	rich.free()

static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	Store.reset_for_tests()
	Store.mark_starter_offered()
	var c := Career.new_game("LIUB", "A", "B", 4)
	c.queue.clear()
	Game.career = c
	for q in c.upgrades_due():
		Development.ai_spend(q)
	Game.goto("matchup")
	await runner.get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("home_waters_matchup.png"))
	Game.goto("training")
	await runner.get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("training.png"))
	Game.goto("more")
	await runner.get_tree().create_timer(0.4).timeout
	Game.current_screen._program()
	await runner.get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("home_waters_program.png"))
	Game.career = null
