extends SceneTree
## Draws the app icon as 32x32 pixel art (a water polo ball bobbing on the pool) and
## exports every size the stores need.
##   godot --headless --path game --script ../tools/make_icon.gd

const W := 32
const WATER := Color("1f7cc4")
const WATER_D := Color("135a9c")
const SHINE := Color("8fd0f5")
const BALL := Color("ffd84a")
const BALL_D := Color("e0a92a")
const BALL_L := Color("fff2a8")
const SEAM := Color("2e5bd6")

func _init() -> void:
	var img := Image.create(W, W, false, Image.FORMAT_RGBA8)
	img.fill(WATER)
	for y in range(0, W, 2):
		for x in W:
			img.set_pixel(x, y, Color("2285cc"))
	var c := Vector2(15.5, 14.5)
	var r := 10.5
	for y in W:
		for x in W:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := p.distance_to(c)
			if d > r:
				continue
			var col := BALL
			var rel := (p - c) / r
			if rel.x + rel.y > 0.75:
				col = BALL_D
			elif rel.x + rel.y < -0.95:
				col = BALL_L
			# three curved seams, like the grip panels of a real ball
			if absf(rel.y - 0.35 * rel.x * rel.x + 0.1) < 0.09:
				col = SEAM
			if absf(rel.x - 0.45 * rel.y * rel.y - 0.2) < 0.08 and rel.y < 0.1:
				col = SEAM
			if absf(rel.x + 0.45 * rel.y * rel.y + 0.25) < 0.08 and rel.y > -0.1:
				col = SEAM
			img.set_pixel(x, y, col)
	# waterline: the bottom of the ball sits in the pool
	for y in range(22, W):
		for x in W:
			var under := img.get_pixel(x, y)
			if under != WATER and under != Color("2285cc"):
				img.set_pixel(x, y, under.lerp(WATER_D, 0.65))
	for x in range(2, 30):
		if x % 3 != 0:
			img.set_pixel(x, 22, SHINE)
	for p in [Vector2i(3, 5), Vector2i(26, 4), Vector2i(27, 27), Vector2i(4, 27), Vector2i(20, 29), Vector2i(10, 26)]:
		img.set_pixel(p.x, p.y, SHINE)
		img.set_pixel(p.x + 1, p.y, SHINE)
	# splash drops
	for p in [Vector2i(3, 18), Vector2i(28, 17), Vector2i(5, 15), Vector2i(26, 14)]:
		img.set_pixel(p.x, p.y, Color.WHITE)
	_save(img, 1024, "res://assets/icon/ios_1024.png")
	_save(img, 256, "res://icon.png")
	_save(img, 192, "res://assets/icon/icon_192.png")
	_save(img, 432, "res://assets/icon/adaptive_fg_432.png")
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(WATER)
	bg.save_png(ProjectSettings.globalize_path("res://assets/icon/adaptive_bg_432.png"))
	print("icons written")
	quit()

func _save(img: Image, size: int, path: String) -> void:
	var out := img.duplicate() as Image
	out.resize(size, size, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	out.save_png(ProjectSettings.globalize_path(path))
