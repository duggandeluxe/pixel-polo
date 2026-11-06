extends "res://src/ui/screens/play_lab.gd"
## Developer Mode's VISUAL UPGRADE TESTING (Settings > Developer Mode): a visual upgrade's levels
## on demand, whatever you own, through the match's own code: a real possession (play_lab) scored,
## then the replay (ReplayBuffer, ReplayShow) or the goal show and GoalFx at the level picked; or
## the stands (CrowdArt) with a full or a quiet crowd.
##   CATEGORY         the six; a category whose effects aren't built yet says so
##   LEVEL 1 .. 4     the level to preview
##   PREVIEW SELECTED plays it    COMPARE LEVELS every level in turn, the same goal
##   GOAL: PLAIN / BAR-DOWN       the goal shown
##   CROWD: QUIET / FULL / CHEER  how many are in, and a goal's reaction (Crowd Atmosphere)
##   GAME: REGULAR / BIG / CONF / NCSA  the win or the entrance previewed (a title: the trophy)
## Broadcast previews use lab numbers (a hat trick, so the milestone shows); in a match they're
## always the match's own.
##   MOTION           Reduce Motion's version (the lab's own)   TEST SKIP   RESET PREVIEW
## Nothing is spent, owned, counted or saved (play_lab's teams; Store.looks is never touched).

var cat_i := 1                # INSTANT REPLAY STUDIO first: the one built so far
var lv := 1
var bar_goal := false
var calm := false
var rec := ReplayBuffer.new()
var show: ReplayShow = null
var clip := {}
var queue: Array = []         # levels still to play (COMPARE)
var scoring := false
var skips := 0
var crowd_full := true
var cheer := 0.0
var goal_run := false         # Goal Celebrations: a goal's show running
var crowd_t := -1.0           # Crowd Atmosphere's COMPARE: s until the next level
var crowd_btn: Button
var game_i := 0               # REGULAR, BIG, CONF, NCSA
var game_btn: Button
var cine = null               # a VictoryShow or PregameIntro playing
var bc: BroadcastFx = null    # Broadcast Presentation's graphic
var rows_ui: Array = []       # the button rows
var schools: Array = []       # NEXT SCHOOL: all 30, made here
var school_i := 0
var cat_btn: Button
var goal_btn: Button
var motion_btn: Button

func lab_title() -> String:
	return "VISUAL UPGRADE TESTING"

func _ready() -> void:
	lab_ready(lab_title())
	var r1 := _row()
	cat_btn = _btn("", func():
		cat_i = (cat_i + 1) % VisualUpgrades.CATS.size()
		_labels(), 150, "Category", "ghost")
	r1.add_child(cat_btn)
	for n in VisualUpgrades.MAX_LEVEL:
		var l: int = n + 1
		r1.add_child(_btn("LEVEL %d" % l, func():
			lv = l
			_labels(), 56, "Level%d" % l))
	var r2 := _row()
	r2.add_child(_btn("PREVIEW SELECTED", preview, 104, "PreviewLevel", "primary"))
	r2.add_child(_btn("COMPARE LEVELS", compare, 92, "Compare"))
	goal_btn = _btn("", func():
		bar_goal = not bar_goal
		clip = {}
		_labels(), 100, "GoalKind", "ghost")
	r2.add_child(goal_btn)
	motion_btn = _btn("", func():
		calm = not calm
		_labels(), 84, "Motion", "ghost")
	r2.add_child(motion_btn)
	var r3 := _row()
	r3.add_child(_btn("TEST SKIP", test_skip, 80, "TestSkip"))
	r3.add_child(_btn("RESET PREVIEW", reset_preview, 92, "ResetPreview", "ghost"))
	crowd_btn = _btn("", func():
		crowd_full = not crowd_full
		_labels(), 90, "CrowdFill", "ghost")
	r3.add_child(crowd_btn)
	r3.add_child(_btn("CHEER", func(): cheer = 1.6, 56, "Cheer"))
	game_btn = _btn("", func():
		game_i = (game_i + 1) % 4
		_labels(), 100, "GameKind", "ghost")
	r3.add_child(game_btn)
	_labels()
	settled.call_deferred()

func _row() -> HBoxContainer:
	var r := UI.hbox(3)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(r)
	rows_ui.append(r)
	return r

func _btn(text: String, cb: Callable, w: int, n: String, style := "normal") -> Button:
	var b := UI.button(text, cb, style, w, 18)
	b.name = n
	b.clip_text = true
	return b

func cat_id() -> String:
	return String(VisualUpgrades.CATS[cat_i].id)

func built() -> bool:
	return lv <= int(VisualUpgrades.BUILT.get(cat_id(), 1))

func _labels() -> void:
	cat_btn.text = String(VisualUpgrades.CATS[cat_i].name)
	goal_btn.text = "GOAL: %s" % ("BAR-DOWN" if bar_goal else "PLAIN")
	motion_btn.text = "MOTION: %s" % ("CALM" if calm else "FULL")
	crowd_btn.text = "CROWD: %s" % ("FULL" if crowd_full else "QUIET")
	game_btn.text = "GAME: %s" % ["REGULAR", "BIG", "CONF", "NCSA"][game_i]
	var top := VisualUpgrades.top(cat_id())
	lv = mini(lv, top)
	for n in VisualUpgrades.MAX_LEVEL:
		var b: Button = find_child("Level%d" % (n + 1), true, false)
		if b != null:
			b.visible = n < top
			UI.style_button(b, "primary" if n + 1 == lv else "normal")
	status = "%s LEVEL %d: %s" % [cat_btn.text, lv, String(VisualUpgrades.CATS[cat_i].tiers[lv - 1][0])]
	if cat_id() == "replay":
		status = "INSTANT REPLAY" if lv >= 2 else "INSTANT REPLAY: LOCKED"

func settled() -> void:
	if goal_run:
		goal_run = false
		if not queue.is_empty():
			lv = queue.pop_front()
			_score_goal()
			return
	if scoring:
		scoring = false
		clip = rec.clip()
		rec.clear()
		_next_show()
		return
	new_play()
	_hold_ball()
	paused = true

func _hold_ball() -> void:
	var s: Swimmer = DefenseFormation.by_tag(play.attackers, "3")
	if s == null:
		s = play.attackers[0]
	s.pos = BarHit.DEMO_FROM
	s.vel = Vector2.ZERO
	s.target = s.pos
	s.facing = 1.0
	play.give_ball(s)

## Scores the goal to show (once; PREVIEW and COMPARE reuse it).
func _score() -> void:
	rec.clear()
	var d := BarHit.demo("bar", false) if bar_goal else {}
	new_play()
	_hold_ball()
	if not d.is_empty():
		play.holder.pos = d.from
		play.holder.target = d.from
	paused = false
	scoring = true
	for i in 30:       # (a moment of real play before the shot, for the clip's build-up)
		play.step(1.0 / 30.0)
		rec.tick(1.0 / 30.0, play.bodies(), ReplayBuffer.ball_of(play.ball, {}), view)
	if d.is_empty():
		play.dev_goal(Geo.GOAL_Y - 0.6, 0.55)
	else:
		play.dev_goal(float(d.cross_y), float(d.height))
	# the sample goal's keeper: a real dive, the wrong way, for the play to run as a shot's own
	if play.ball.state == Ball.State.SHOT:
		var way: int = KeeperDive.RIGHT if float(play.ball.shot.cross_y) < play.keeper.pos.y else KeeperDive.LEFT
		play.ball.shot["dive"] = KeeperDive.from_body(KeeperDive.body_of(play.keeper.player), way, play.keeper.pos.y).to_dict()
		play.ball.shot["keeper_go"] = 0.14

## A goal for Goal Celebrations: the match's own show at level `lv`.
func _score_goal() -> void:
	var d := BarHit.demo("bar", false) if bar_goal else {}
	new_play()
	_hold_ball()
	if not d.is_empty():
		play.holder.pos = d.from
		play.holder.target = d.from
	paused = false
	goal_run = true
	status = "LEVEL %d: %s" % [lv, String(VisualUpgrades.CATS[cat_i].tiers[lv - 1][0])]
	if d.is_empty():
		play.dev_goal(Geo.GOAL_Y - 0.6, 0.55)
	else:
		play.dev_goal(float(d.cross_y), float(d.height))

func _show_stands() -> void:
	new_play()
	paused = true
	status = "CROWD LEVEL %d: %s" % [lv, String(VisualUpgrades.cat("crowd").tiers[lv - 1][0])]

## Plays the picked level. False if that category's effects don't exist yet.
func preview() -> bool:
	if not built():
		status = "%s: NOT BUILT YET" % cat_btn.text
		return false
	queue.clear()
	match cat_id():
		"goal", "broadcast":
			_score_goal()
		"crowd":
			_show_stands()
		"victory", "pregame":
			_play_cine(lv)
		_:
			if lv == 1:
				_score_goal()   # LOCKED: the goal's own show, then straight on
				status = "LOCKED: THE GOAL, THEN THE RESTART"
			else:
				queue = [ReplayShow.CINEMATIC]
				_start()
	return true

## A win or an entrance at level `l`: the match's own object, on the stage.
func _play_cine(l: int) -> void:
	if cat_id() == "victory":
		cine = VictoryShow.new(us, l, ["", "", "conf", "nat"][game_i], game_i == 1, calm or HotFire.calm())
		cine.crowd = lab_crowd()
		cine.score = [12, 9]
	else:
		var it := PregameIntro.new(us, them, true, ["REGULAR SEASON", "REGULAR SEASON", "CONFERENCE TOURNAMENT", "NCSA CHAMPIONSHIP"][game_i], "")
		it.calm = calm or HotFire.calm()
		it.set_level(l)
		var ev := PoolView.new()
		ev.width = maxf(stage_cv.size.x, 120.0)
		ev.height = maxf(stage_cv.size.y, 80.0)
		ev.snap_to(Sprint.new(us, them, 0.0).focus())
		it.end_view = ev
		cine = it
	status = "LEVEL %d: %s" % [l, String(VisualUpgrades.CATS[cat_i].tiers[l - 1][0])]

## The next school's real colours and logo on the stage (of all 30).
func next_school() -> String:
	if schools.is_empty():
		schools = Career.new_setup(777).teams.values()
	school_i = (school_i + 1) % schools.size()
	us = schools[school_i]
	them = schools[(school_i + 7) % schools.size()]
	clip = {}
	settled()
	status = Colleges.display_name(us.name).to_upper()
	return us.id

func lab_goal(who: PoloPlayer) -> void:
	if cat_id() == "broadcast":
		bc = BroadcastFx.new(lv, calm or HotFire.calm())
		bc.goal(who, us, 3, 5, "3-2")

func compare() -> bool:
	match cat_id():
		"goal", "broadcast":
			queue = range(2, VisualUpgrades.top(cat_id()) + 1)
			lv = 1
			_score_goal()
		"victory", "pregame":
			queue = range(2, VisualUpgrades.top(cat_id()) + 1)
			_play_cine(1)
		"crowd":
			lv = 1
			crowd_t = 2.0
			_show_stands()
		_:
			queue = [ReplayShow.PLAIN, ReplayShow.CINEMATIC]   # (the two presentations; LOCKED has nothing to show)
			_start()
	return true

func _start() -> void:
	if clip.is_empty():
		_score()
	else:
		_next_show()

func _next_show() -> void:
	if queue.is_empty() or clip.is_empty():
		show = null
		status = "DONE  (PREVIEW AGAIN TO REPLAY)" if not clip.is_empty() else "NOTHING RECORDED"
		return
	var l: int = queue.pop_front()
	show = ReplayShow.new(clip, l, calm or HotFire.calm())
	show.who = "LAB PLAYER"
	show.team = Colleges.short_name(us).to_upper()
	show.col = US_CAP
	show.paint_body = func(ci: CanvasItem, v: PoolView, sw: Swimmer): PoolArt.draw_body(ci, v, sw, _cap(sw), _trim(sw))
	status = "INSTANT REPLAY: %s" % ("CINEMATIC" if l == ReplayShow.CINEMATIC else "BASIC")

func test_skip() -> bool:
	if cine != null:
		cine.skip()
		cine = null
		queue.clear()
		skips += 1
		status = "SKIPPED: BACK TO THE LAB"
		return true
	if show == null:
		if not preview():
			return false
		if show == null:
			return true   # (scoring first: the skip test runs on the next press)
	show.skip()
	skips += 1
	status = "SKIPPED: BACK TO THE LAB"
	show = null
	queue.clear()
	return true

func reset_preview() -> void:
	if show != null:
		show.skip()
	show = null
	queue.clear()
	clip = {}
	rec.clear()
	scoring = false
	goal_run = false
	crowd_t = -1.0
	cheer = 0.0
	cine = null
	bc = null
	game_i = 0
	lv = 1
	calm = false
	bar_goal = false
	_labels()
	settled()

func lab_goal_level() -> int:
	return lv if cat_id() == "goal" else 1

func lab_style() -> Dictionary:
	if cat_id() != "crowd":
		return {}
	return CrowdArt.style(lv, us, them, false, lab_crowd(), calm or HotFire.calm(), 0)

func lab_crowd() -> float:
	return (0.95 if crowd_full else 0.45) if cat_id() == "crowd" else 0.6

func lab_excite() -> float:
	return cheer

func fire_still() -> bool:
	return calm or HotFire.calm()

## The stands in the picture for Crowd Atmosphere; the attack otherwise.
func focus() -> Vector2:
	return Vector2(Geo.HALF, 0.0) if cat_id() == "crowd" else view.attack_frame(play)

func _process(dt: float) -> void:
	cheer = maxf(0.0, cheer - dt * 0.6)
	if crowd_t >= 0.0:
		crowd_t -= dt
		if crowd_t < 0.0:
			if lv < VisualUpgrades.top("crowd"):
				lv += 1
				crowd_t = 2.0
				_show_stands()
	if cat_id() == "crowd" and play != null:
		view.width = maxf(stage_cv.size.x, 120.0)
		view.height = maxf(stage_cv.size.y, 80.0)
		view.snap_to(focus())
	if bc != null:
		bc.step(dt)
	if cine != null:
		cine.step(dt)
		if cine.done:
			cine = null
			if not queue.is_empty():
				_play_cine(queue.pop_front())
			else:
				status = "DONE  (PREVIEW AGAIN TO REPLAY)"
		stage_cv.queue_redraw()
		return
	if show != null:
		show.step(dt)
		if show.done:
			_next_show()
		stage_cv.queue_redraw()
		return
	super(dt)
	if scoring and play != null:
		rec.tick(dt * goal_show.time_scale() * bar_show.play_scale(), play.bodies(), ReplayBuffer.ball_of(play.ball, _net()), view)

func _draw_stage(ci: Control) -> void:
	if cine != null:
		cine.draw(ci, ci.size)
		return
	if show != null:
		show.draw(ci, ci.size)
		return
	super(ci)
	if bc != null:
		bc.draw(ci, ci.size, false, false, scratch)
