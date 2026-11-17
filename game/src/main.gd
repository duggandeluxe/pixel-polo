extends Node
## Boot: sets up the screen root + overlay layer, then shows the title (or runs tests).
##   godot --path game -- --test all            headless checks
##   godot --path game -- --shot /path/out.png  smoke screenshot of the title
##   godot --headless --path game -- --relay 24790   run the online relay (see relay/README.md)

func _ready() -> void:
	var root := Control.new()
	root.name = "Screens"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var ov := CanvasLayer.new()
	ov.layer = 10
	add_child(ov)
	Game.register_main(self, root, ov)
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--relay":
		var relay := RelayServer.new()
		add_child(relay)
		if relay.start(int(args[1])) != OK:
			push_error("relay: can't listen on %s" % args[1])
			get_tree().quit(1)
		return
	if args.size() > 0 and args[0] == "--test" and DevGate.allowed():   # (tests: development builds only)
		Game.test_mode = true
		# tests read the English text: whatever LANGUAGE the player picked, they run in English
		# (Game.settings keeps the pick, so a test that saves settings never loses it)
		Loc.apply(Loc.DEFAULT, false)
		var runner = load("res://tests/test_runner.gd").new()
		add_child(runner)
		runner.run(args.slice(1))
		return
	Game.goto("title")
	# every other screen compiled in the background from here, so none stalls on its first visit
	get_tree().create_timer(0.4).timeout.connect(Game.start_warmup)
	if args.size() >= 2 and args[0] == "--shot" and DevGate.allowed():
		await get_tree().create_timer(3.0).timeout
		get_viewport().get_texture().get_image().save_png(args[1])
		get_tree().quit()
