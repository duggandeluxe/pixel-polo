extends RefCounted
## Screenshot tour of the HOT star animations (StarFx): the form lab paused through each phase
## of heating up and cooling down, then a real roster card heating up in the DEV panel. Needs a window:
##   godot --path game -- --test star_fx_png <dir>

const HEAT := [0.1, 0.22, 0.28, 0.4, 0.5, 0.8]
const COOL := [0.05, 0.2, 0.3]

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	Store.reset_for_tests()
	var dev_was: bool = Game.settings.get("dev_mode", false)
	Game.settings.dev_mode = true
	Game.career = null
	Game.goto("form_lab")
	await tree.create_timer(0.3).timeout
	var lab = Game.current_screen
	lab.cur = 3.0
	lab.pot = 5.0
	await _frozen(runner, out, lab, lab.card, lab.fx, PlayerForm.NORMAL, PlayerForm.HOT, HEAT, "heat")
	await _frozen(runner, out, lab, lab.card, lab.fx, PlayerForm.HOT, PlayerForm.VERY_HOT, HEAT, "heat2")
	await _frozen(runner, out, lab, lab.card, lab.fx, PlayerForm.VERY_HOT, PlayerForm.HOT, COOL, "cool")
	lab.state = PlayerForm.VERY_HOT
	lab.card.queue_redraw()
	await _shot(runner, out, "sfx_lab_very_hot")
	# a real card
	var c := Career.new_game("CULA", "Shot", "Coach", 4)
	Game.career = c
	Game.goto("roster")
	await tree.create_timer(0.3).timeout
	var scr = Game.current_screen
	var p: PoloPlayer = c.team().roster[1]
	scr._dev_toggle()
	scr._dev_select(p.id)
	p.form = []
	for pl: PoloPlayer in c.team().roster:
		pl.stars = 3.0
		pl.pot_stars = 5.0
	var heats := [2, 1, 0, 0, 1, 0, 2]
	for i in c.team().roster.size():
		if c.team().roster[i] != p:
			c.team().roster[i].heat = heats[i % heats.size()]
	for i in [1, 0]:
		var fx: StarFx = scr.fxs[p.id]
		scr._dev_form(1)
		fx._tw.pause()
		fx.t = 0.4
		scr.cards[p.id].queue_redraw()
		await _shot(runner, out, "sfx_roster_heat%d" % i)
		fx.t = 0.9
		scr.cards[p.id].queue_redraw()
		await _shot(runner, out, "sfx_roster_hot%d" % i)
	Game.settings.dev_mode = dev_was
	Game.career = null
	Game.goto("title")

static func _frozen(runner: Node, out: String, lab, card: Control, fx: StarFx, from: String, to: String, times: Array, name: String) -> void:
	lab.state = to
	fx.play(from, to)
	fx._tw.pause()
	for t in times:
		fx.t = t
		card.queue_redraw()
		await _shot(runner, out, "sfx_%s_%03d" % [name, int(t * 100)])
	fx._tw.kill()
	fx.kind = ""

static func _shot(runner: Node, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	runner.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("  shot ", name)
