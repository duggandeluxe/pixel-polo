extends RefCounted
## NEW RECRUITS AVAILABLE: every Recruiting.AUTO_EVERY of your games the market rolls for free
## (Recruiting.after_game) without touching the REFRESH price, the hub's COACHING button gets its
## gold banner and dot, Coaching alone keeps them, opening Recruiting clears them, and the
## unread state is saved.
##   godot --headless --path game -- --test new_recruits
##   godot --path game --resolution 480x270 -- --test new_recruits_png <outdir>

var r   # the test runner

func run(runner) -> void:
	r = runner
	print("new recruits available")
	Store.reset_for_tests()
	_roll()
	_closed_market()
	_saves()
	await _hub()
	Game.career = null
	Game.goto("title")
	await r.get_tree().process_frame

func _career(seed_value: int = 77) -> Career:
	var c := Career.new_game("GWU", "A", "B", seed_value)
	c.queue.clear()
	c.hot_tip = true
	Game.career = c
	return c

func _ids(c: Career) -> Array:
	return c.market.map(func(x): return (x.p as PoloPlayer).id)

## Plays (sims) your next game, moving the weeks on until there is one. Returns false at the season's end.
func _next_game(c: Career) -> bool:
	for _i in 40:
		if c.season_over_for_me() or c.phase != "season":
			return false
		if c.has_game():
			c.sim_my_game()
			return true
		c.end_week()
	return false

func _roll() -> void:
	var c := _career()
	r.check(not c.new_recruits and c.auto_games == 0, "a new dynasty: nothing unread, nothing counted")
	# one paid refresh first, so the price has somewhere to stay
	c.credits = 500
	Recruiting.refresh(c)   # (the season's free one)
	var cost := Recruiting.refresh_cost(c)
	var refreshes := c.refreshes
	var pin: Dictionary = c.market[0]
	Recruiting.toggle_pin(c, pin)
	var before := _ids(c)
	var wallet := c.wallet()
	r.check(_next_game(c), "a first game to play")
	r.check(_ids(c) == before and not c.new_recruits, "one game: no roll yet, nothing unread")
	r.check(_next_game(c), "a second game to play")
	var after := _ids(c)
	r.check(c.new_recruits, "two games: NEW RECRUITS AVAILABLE")
	r.check(c.market.size() == Recruiting.MARKET_SIZE, "the rolled market is full")
	r.check(pin in c.market and Recruiting.is_pinned(pin), "the pinned prospect stays through the roll")
	var fresh := after.filter(func(id): return not id in before)
	r.check(fresh.size() >= Recruiting.MARKET_SIZE - 1, "every unpinned prospect replaced (%d new)" % fresh.size())
	r.check(c.refreshes == refreshes and Recruiting.refresh_cost(c) == cost, "the roll is free: REFRESH's price unchanged (%d)" % Recruiting.refresh_cost(c))
	r.check(c.wallet() >= wallet, "the roll costs nothing (game credits only add)")
	r.check(c.auto_games == 0, "the count starts again")
	# another roll before Recruiting is seen: still one notice, still unread
	_next_game(c)
	_next_game(c)
	r.check(c.new_recruits, "a second roll before Recruiting is seen: still unread")
	r.check(Recruiting.seen_new(c) and not c.new_recruits, "opening Recruiting reads it")
	r.check(not Recruiting.seen_new(c), "...once")
	# a manual refresh never raises it
	Recruiting.refresh(c)
	r.check(not c.new_recruits, "a paid REFRESH RECRUITS: no notice")

func _closed_market() -> void:
	var c := _career(78)
	c.phase = "cuts"
	var before := _ids(c)
	for _i in 4:
		Recruiting.after_game(c)
	r.check(_ids(c) == before and not c.new_recruits, "the market closed (roster cuts): no roll, no notice")
	c.phase = "season"
	c.auto_games = 5
	c.start_season()
	r.check(c.auto_games == 0 and not c.new_recruits, "a new season starts the count again (no notice for the new class)")

func _saves() -> void:
	var c := _career(79)
	_next_game(c)
	var d := c.to_dict()
	var back := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	r.check(back.auto_games == 1, "the game count is saved")
	_next_game(c)
	back = Career.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	r.check(back.new_recruits, "NEW RECRUITS AVAILABLE is saved unread")
	d = c.to_dict()
	d.erase("auto_games")
	d.erase("new_recruits")
	var old := Career.from_dict(JSON.parse_string(JSON.stringify(d)))
	r.check(old.auto_games == 0 and not old.new_recruits, "an older save loads with nothing unread")

func _frames(n: int = 3) -> void:
	for _i in n:
		await r.get_tree().process_frame

func _hub() -> void:
	var c := _career(80)
	Game.goto("hub")
	await _frames()
	var nav: Control = Game.current_screen.find_child("Nav_coaching", true, false)
	r.check(nav != null and nav.find_child("RecruitsNotice", true, false) == null, "no notice before a roll")
	var size_before := nav.size if nav != null else Vector2.ZERO
	_next_game(c)
	_next_game(c)
	Game.goto("hub")
	await _frames()
	nav = Game.current_screen.find_child("Nav_coaching", true, false)
	var banner: Control = nav.find_child("RecruitsNotice", true, false) if nav != null else null
	var dot: Control = nav.find_child("RecruitsDot", true, false) if nav != null else null
	r.check(banner != null and dot != null, "after the roll: the banner and the dot on COACHING")
	if banner != null:
		r.check(banner.get_global_rect().end.y <= nav.get_global_rect().position.y, "the banner sits above the button")
		r.check(banner.mouse_filter == Control.MOUSE_FILTER_IGNORE and dot.mouse_filter == Control.MOUSE_FILTER_IGNORE, "neither takes a tap")
	r.check(nav.size == size_before, "COACHING's size is unchanged")
	Game.goto("coaching")
	await _frames()
	r.check(c.new_recruits, "opening Coaching alone keeps it")
	Game.goto("hub")
	await _frames()
	nav = Game.current_screen.find_child("Nav_coaching", true, false)
	r.check(nav.find_child("RecruitsNotice", true, false) != null, "...and the hub still shows it")
	Game.goto("recruiting", {"from": "coaching"})
	await _frames()
	r.check(not c.new_recruits, "opening Recruiting clears it")
	Game.goto("hub")
	await _frames()
	nav = Game.current_screen.find_child("Nav_coaching", true, false)
	r.check(nav.find_child("RecruitsNotice", true, false) == null and nav.find_child("RecruitsDot", true, false) == null, "back on the hub: banner and dot gone")

# ------------------------------------------------------------------ screenshots
static func shots(runner, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = runner.get_tree()
	Store.reset_for_tests()
	var c := Career.new_game("GWU", "Sam", "Rivera", 31)
	c.queue.clear()
	c.hot_tip = true
	Game.career = c
	c.new_recruits = true
	Game.goto("hub")
	await tree.create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("nr_hub.png"))
	print("  shot nr_hub")
