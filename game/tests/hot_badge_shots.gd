extends RefCounted
## The HOT / VERY HOT burning stars (HotBadge) on roster cards, 4x: NORMAL, HOT, VERY HOT, the keeper
## HOT, a sub VERY HOT, an injured HOT; then the fire's flicker frames, HOT and VERY HOT. Game.test_mode stays on, so nothing is saved. Needs a window:
##   godot --path game --resolution 640x360 -- --test hot_badge_png <dir>

const Roster := preload("res://src/ui/screens/roster.gd")
const HotBadge := preload("res://src/ui/hot_badge.gd")

static func run(runner: Node, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := runner.get_tree()
	var t := League.make_team(1, 1)
	var seven := t.starters()
	Development.injure(seven[5], RandomNumberGenerator.new(), "moderate")
	var vp := SubViewport.new()
	vp.size = Vector2i(660, 130)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	runner.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("06102e")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var cases := [[seven[1], PlayerForm.NORMAL, false], [seven[2], PlayerForm.HOT, false], [seven[3], PlayerForm.VERY_HOT, false],
		[seven[0], PlayerForm.HOT, false], [seven[4], PlayerForm.VERY_HOT, true], [seven[5], PlayerForm.HOT, false]]
	for i in cases.size():
		var p: PoloPlayer = cases[i][0]
		var fx := StarFx.new()
		var st: String = cases[i][1]
		var bench: bool = cases[i][2]
		vp.add_child(_painter(Vector2(4 + i * 108, 4), Roster.CARD,
			func(ci): Roster.paint_card(ci, p, t, fx, st, UI.TEXT, bench, false, true, false)))
	var ts := [0.0, HotBadge.FLICKER, HotBadge.FLICKER * 2.0]
	for i in ts.size():
		for j in 2:
			var tt: float = ts[i]
			var st2: String = [PlayerForm.HOT, PlayerForm.VERY_HOT][j]
			vp.add_child(_painter(Vector2(4 + (i * 2 + j) * 66, 76), Vector2(64, 26), func(ci):
				ci.draw_rect(Rect2(0, 0, 64, 26), Roster.INFO_BG)
				var c: float = 3.5 if i == 2 else 3.0
				HotBadge.under(ci, Vector2(2, 10), c, 5.0, st2, tt)
				Deck.star_bar(ci, 2, 10, c, 5.0, PlayerForm.red_stars(st2))
				HotBadge.over(ci, Vector2(2, 10), c, 5.0, st2)))
	# the player page's attribute number with its HOT part in red: NORMAL, HOT, VERY HOT, a half, a ten
	var vals := [[8.0, 0.0], [8.0, 0.5], [8.0, 1.0], [7.5, 0.5], [10.0, 0.5]]
	for i in vals.size():
		var v: float = vals[i][0]
		var h: float = vals[i][1]
		vp.add_child(_painter(Vector2(4 + i * 80, 106), Vector2(78, 20), func(ci):
			ci.draw_rect(Rect2(0, 0, 78, 20), Roster.INFO_BG)
			DevArt.draw_value(ci, 74, 10, v, h)))
	for _i in 3:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	img.save_png(out.path_join("hot_badges.png"))
	print("saved ", out.path_join("hot_badges.png"))
	vp.queue_free()

class Painter extends Control:
	var cb: Callable
	func _draw() -> void:
		cb.call(self)

static func _painter(at: Vector2, size: Vector2, cb: Callable) -> Control:
	var c := Painter.new()
	c.position = at
	c.size = size
	c.cb = cb
	return c
