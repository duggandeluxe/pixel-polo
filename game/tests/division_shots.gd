extends RefCounted
## Screens of the expansion, for looking at: --test division_png <dir> (needs a window).
static func shots(runner: Node, out: String) -> void:
	Game.test_mode = true
	Store.reset_for_tests()
	Store.packs = ["div2"]
	await _go(runner, "new_career", {})
	await _shot(runner, out, "picker_all")
	var scr = _screen(runner)
	scr.div_filter = 2
	scr._render()
	await _wait(runner)
	await _shot(runner, out, "picker_d2")
	scr.div_filter = 3
	scr._render()
	await _wait(runner)
	await _shot(runner, out, "picker_d3_locked")
	scr.div_filter = 0
	scr.pick = "D2_02"
	scr.step = 1
	scr._render()
	await _wait(runner)
	await _shot(runner, out, "coach_step")
	Store.packs = ["div2", "div3"]
	var c := DivisionChecks.sandbox("D3_04", [1, 2, 3], 7)
	Game.career = c
	DivisionChecks.sim_season(c)
	c.queue = []
	await _go(runner, "conference", {})
	scr = _screen(runner)
	await _shot(runner, out, "standings_sciac")
	scr.conf = "NEWPC"
	scr._render()
	await _wait(runner)
	await _shot(runner, out, "standings_nwpc")
	scr.tab = "PLAYOFFS"
	scr.pfam = "d3"
	scr._render()
	await _wait(runner)
	await _shot(runner, out, "bracket_d3")
	scr.pfam = "conf"
	scr.pconf = "WWPA"
	scr._render()
	await _wait(runner)
	await _shot(runner, out, "bracket_wwpa")
	scr.pfam = "nat"
	scr._render()
	await _wait(runner)
	await _shot(runner, out, "bracket_nat")
	await _go(runner, "trophy_room", {"team": String(c.champions_log[0].d3), "back_to": "hub"})
	await _shot(runner, out, "trophy_d3")
	await _go(runner, "trophy_room", {"team": String(c.champions_log[0].d2), "back_to": "hub"})
	await _shot(runner, out, "trophy_d2")
	await _go(runner, "store", {})
	await _shot(runner, out, "store")
	await _go(runner, "division_lab", {})
	await _shot(runner, out, "lab")
	Store.reset_for_tests()

static func _screen(_runner: Node):
	return Game.current_screen

static func _go(runner: Node, name: String, params: Dictionary) -> void:
	Game.goto(name, params, false)
	await _wait(runner)

static func _wait(runner: Node) -> void:
	for _i in 12:
		await runner.get_tree().process_frame

static func _shot(runner: Node, out: String, name: String) -> void:
	await _wait(runner)
	await runner.get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join("div_%s.png" % name))
