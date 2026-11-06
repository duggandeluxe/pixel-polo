extends RefCounted
## Instant Replay: ReplayBuffer records what was really on the water, ReplayShow plays it at its
## levels while the match waits, and a match with replays ends exactly as one without.
##   godot --headless --path game -- --test replay
## Screenshots (needs a window): --test replay_png <dir>

var r

func run(runner) -> void:
	r = runner
	print("instant replay")
	Store.reset_for_tests()
	await _match_unchanged()
	await _during_a_replay()
	_levels()
	_settings_and_sale()
	await _lab()
	Store.reset_for_tests()
	Game.career = null

func _frames(n: int = 2) -> void:
	for i in n:
		await r.get_tree().process_frame

func _cfg(extra: Dictionary) -> Dictionary:
	var d := {"us": League.make_team(2, 1), "them": League.make_team(3, 1), "seed": 77, "minutes": 2.0, "autoplay": true, "intro": false, "replay_level": 2}
	d.merge(extra, true)
	return d

## Runs a bot match to the end; skips each replay at once when `skip`.
func _play(ms, skip: bool) -> void:
	var guard := 0
	while ms.flow.phase != MatchFlow.Phase.FINAL and guard < 200000:
		guard += 1
		ms._process(1.0 / 30.0)
		if ms.flow.phase == MatchFlow.Phase.BREAK and not ms.flow.state.is_last_quarter():
			ms.flow.break_done()   # (the break waits for a tap)
		if ms.replay != null and skip:
			ms.replay.skip()
			ms._end_replay()

func _match_unchanged() -> void:
	Game.match_cfg = _cfg({"replay": false})
	Game.goto("match", Game.match_cfg)
	await _frames(2)
	var plain = Game.current_screen
	r.check(plain.rec == null, "no recording when replays are off")
	_play(plain, false)
	r.check(plain.flow.phase == MatchFlow.Phase.FINAL, "the bot match reaches the final whistle")
	var want: Array = plain.flow.state.score.duplicate()
	var want_shots: Array = plain.flow.state.shots.duplicate()
	Game.match_cfg = _cfg({"replay": true})
	Game.goto("match", Game.match_cfg)
	await _frames(2)
	var ms = Game.current_screen
	_play(ms, true)
	var st: MatchState = ms.flow.state
	r.check(ms.flow.phase == MatchFlow.Phase.FINAL, "...with replays too")
	r.check(st.score == want and st.shots == want_shots, "a match with replays ends exactly the same: %s, shots %s" % [str(st.score), str(st.shots)])
	r.check(ms.replays_done >= 1 and ms.replays_done <= int(st.score[0]) + int(st.score[1]), "%d replays of %d goals (never more than goals)" % [ms.replays_done, int(st.score[0]) + int(st.score[1])])

func _during_a_replay() -> void:
	Game.match_cfg = _cfg({"replay": true})
	Game.goto("match", Game.match_cfg)
	await _frames(2)
	var ms = Game.current_screen
	var guard := 0
	while ms.replay == null and guard < 100000:
		guard += 1
		ms._process(1.0 / 30.0)
	r.check(ms.replay != null, "a goal brings a replay")
	if ms.replay == null:
		return
	var st: MatchState = ms.flow.state
	var before := [st.clock, st.score.duplicate(), st.shots.duplicate(), ms.flow.phase, ms.flow.play, ms.flow.play.shot_clock if ms.flow.play != null else 0.0, ms.flow.events.size()]
	var clip: Dictionary = ms.replay.clip
	var fr: Array = clip.frames
	r.check(int(clip.shot) < int(clip.net) and int(clip.net) < fr.size() and bool(fr[int(clip.shot)].ball.shot) and not fr.is_empty(), "a clip: the build-up, the release, the ball going in")
	var moved := (fr[int(clip.net)].ball.at as Vector3).distance_to(fr[int(clip.shot)].ball.at) > 1.0
	r.check(moved and (fr[0].men as Array).size() >= 2, "recorded positions: the ball really travels, every man's there")
	var seen_end := false
	for i in 600:
		ms._process(1.0 / 30.0)
		if ms.replay == null:
			seen_end = true
			break
		var now := [st.clock, st.score, st.shots, ms.flow.phase, ms.flow.play, ms.flow.play.shot_clock if ms.flow.play != null else 0.0, ms.flow.events.size()]
		if str(now) != str(before):
			r.check(false, "the match moved during a replay: %s vs %s" % [str(now), str(before)])
			break
	r.check(seen_end, "the replay ends by itself; nothing moved while it played")
	var g: int = int(st.score[0]) + int(st.score[1])
	r.check(g == int(before[1][0]) + int(before[1][1]) + 1 or g == int(before[1][0]) + int(before[1][1]), "the goal's counted once")
	# skipping
	guard = 0
	while ms.replay == null and guard < 100000 and ms.flow.phase != MatchFlow.Phase.FINAL:
		guard += 1
		ms._process(1.0 / 30.0)
	if ms.replay != null:
		var done: int = ms.replays_done
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ms._input(ev)
		ms._input(ev)
		r.check(ms.replay == null and ms.replays_done == done + 1, "a click skips it, once")
	Game.goto("title")
	await _frames(1)

func _fake_clip(bar := -1) -> Dictionary:
	var frames: Array = []
	for i in 90:
		frames.append({"men": [], "ball": {"at": Vector3(10 + i * 0.2, 10, 0.5), "shot": i >= 40 and i <= 60, "dir": Vector2(1, 0), "power": 0.5, "fire": 0, "flown": 0.2, "net": {}},
			"cam": Vector2(15, 2), "zoom": 1.0, "mirror": false})
	return {"frames": frames, "shot": 40, "net": 60, "bar": bar, "bar_text": "BAR-DOWN!" if bar >= 0 else ""}

func _run_length(s: ReplayShow) -> float:
	var n := 0
	while not s.done and n < 2000:
		s.step(1.0 / 60.0)
		n += 1
	return n / 60.0

func _levels() -> void:
	r.check(ReplayShow.new(_fake_clip(), 1).done, "Level 1 NO REPLAY: no show")
	var two := ReplayShow.new(_fake_clip(), 2)
	r.check(two.plan().size() == 1 and float(two.plan()[0].speed) == 1.0 and two.cam_mode() == "rec", "Level 2: normal speed, the game's camera")
	var three := ReplayShow.new(_fake_clip(50), 3)
	r.check(three.cam_mode() == "shooter" and String(three.plan()[1].cam) == "ball" and float(three.plan()[1].speed) < 1.0, "Level 3: in on the shooter, then the ball, in slow motion")
	var froze := false
	var at := -1
	while not three.done:
		three.step(1.0 / 60.0)
		if three.frozen():
			froze = true
			at = three.frame_index()
	r.check(froze and at == 50, "Level 3: the picture freezes on the frame it hit the bar")
	var plain := ReplayShow.new(_fake_clip(), 3)
	var at2 := -1
	while not plain.done:
		plain.step(1.0 / 60.0)
		if plain.frozen():
			at2 = plain.frame_index()
	r.check(at2 == 60, "...and on the ball crossing the line otherwise")
	var lens := []
	for l in [2, 3]:
		lens.append(_run_length(ReplayShow.new(_fake_clip(), l)))
	r.check(lens.all(func(x): return x > 1.0 and x < 12.0), "every level stays short (%s s)" % str(lens))
	var c := ReplayShow.new(_fake_clip(), 3, true)
	r.check(c.plan().all(func(p): return String(p.cam) == "rec" and not p.has("ramp")), "Reduce Motion: the recorded camera, no ramps")
	var sk := ReplayShow.new(_fake_clip(), 3)
	sk.skip()
	sk.skip()
	r.check(sk.done and sk.skipped, "skip")
	r.check(ReplayShow.new({}, 2).done, "nothing recorded: no replay")

func _settings_and_sale() -> void:
	var kept: bool = Game.settings.get("auto_replay", true)
	Game.settings.auto_replay = false
	Game.match_cfg = _cfg({"replay": true})
	var ms = load("res://src/match/match_screen.gd").new()
	ms.setup(Game.match_cfg)
	r.check(ms.rec == null, "AUTOMATIC REPLAYS off: nothing recorded, no replay")
	ms.free()
	Game.settings.auto_replay = kept
	Store.reset_for_tests()
	Store.bank.credit(500, "T-R")
	r.check(Store.buy_tier("replay") == "" and Store.looks.level("replay") == 2 and Store.vault == 0, "one unlock, 500")
	r.check(Store.buy_tier("replay") == "MAX LEVEL UNLOCKED", "...and that's all there is")
	Store.reset_for_tests()

func _lab() -> void:
	Game.settings.dev_mode = true
	Game.goto("settings")
	await _frames(3)
	r.check(Game.current_screen.find_child("VisualLab", true, false) != null, "VISUAL UPGRADE TESTING in Developer Mode")
	Game.goto("visual_lab")
	await _frames(3)
	var lab = Game.current_screen
	r.check(lab.cat_id() == "replay", "starts on the category built so far")
	lab.lv = 2
	r.check(lab.preview(), "PREVIEW SELECTED")
	var guard := 0
	while lab.show == null and guard < 2000:
		guard += 1
		lab._process(1.0 / 30.0)
	r.check(lab.show != null and lab.show.level == 3 and not lab.clip.is_empty(), "a real goal, recorded, shown at Level 3")
	lab.test_skip()
	r.check(lab.show == null and lab.skips == 1, "TEST SKIP")
	r.check(lab.compare() and lab.show != null and lab.show.level == ReplayShow.PLAIN and lab.queue == [ReplayShow.CINEMATIC], "COMPARE: both presentations, the same goal")
	lab.reset_preview()
	r.check(lab.show == null and lab.clip.is_empty() and lab.lv == 1, "RESET PREVIEW")
	r.check(Store.looks.level("replay") == 1 and Store.vault == 0, "previews own and spend nothing")
	Game.settings.dev_mode = false
	Game.goto("title")
	await _frames(1)
