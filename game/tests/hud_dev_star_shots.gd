extends RefCounted
## The match HUD's bottom-left holder tag (Hud.holder_tag) for a regular player, a regular HOT
## player, and both DEV recruits (one HOT): a DEV recruit's stars light blue (Hud.DEV_STAR), everyone
## else's gold, HOT red kept. Needs a window:
##   godot --path game -- --test hud_dev_stars_png <dir>

class Painter extends Node2D:
	var players: Array = []
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 200, 4 + players.size() * 16), Color("1d5f8a"))
		for i in players.size():
			Hud.holder_tag(self, Vector2(4, 4 + i * 16), players[i])

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	var reg := DevRecruits.make("blake")
	reg.dev_recruit = ""   # the same man without the DEV mark: gold
	reg.first = "Joe"
	reg.last = "Regular"
	reg.stars = 3.5
	var hot := DevRecruits.make("logan")
	hot.dev_recruit = ""
	hot.first = "Hot"
	hot.last = "Regular"
	hot.stars = 2.5
	hot.heat = 1
	var blake := DevRecruits.make("blake")
	blake.stars = 3.5
	var logan := DevRecruits.make("logan")
	logan.stars = 2.5
	logan.heat = 2
	var vp := SubViewport.new()
	vp.size = Vector2i(200, 4 + 4 * 16)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	runner.add_child(vp)
	var pn := Painter.new()
	pn.players = [reg, hot, blake, logan]
	vp.add_child(pn)
	for _i in 4:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join("hud_dev_stars.png"))
	print("hud_dev_stars: is_dev ", [DevRecruits.is_dev(reg), DevRecruits.is_dev(hot), DevRecruits.is_dev(blake), DevRecruits.is_dev(logan)],
		" red ", [PlayerForm.red_stars(hot.form_state()), PlayerForm.red_stars(logan.form_state())])
	vp.queue_free()
