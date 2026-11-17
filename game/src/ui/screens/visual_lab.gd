extends "res://src/ui/screens/play_lab.gd"
## Developer Mode's VISUAL UPGRADE TESTING (Settings > Developer Mode): a visual upgrade's levels
## on demand, whatever you own, through the match's own code: a real possession (play_lab) scored,
## then the goal show and GoalFx at the level picked; or the stands (CrowdArt) at each Crowd
## Atmosphere level, for any of the 30 home schools.
##   CATEGORY         the five; a category whose effects aren't built yet says so
## SCOREBOARD: the board at the level picked over the stage (a late, close game), the goal going
## up on it; the full tool is SCOREBOARD VISUAL PREVIEW (scoreboard_lab.gd).
##   LEVEL 1 .. 4     the level to preview
##   PREVIEW SELECTED plays it    COMPARE LEVELS every level in turn, the same goal
##   GOAL: PLAIN / BAR-DOWN       the goal shown
##   HOME: <SCHOOL> / CHEER       the home school (all 30, its real colours) and a goal's reaction;
##                                Crowd Atmosphere's status line says how full the stands are
##   GAME: REGULAR / BIG / CONF / NCSA  the entrance previewed
## Broadcast previews use lab numbers (a hat trick, so the milestone shows); in a match they're
## always the match's own.
##   MOTION           Reduce Motion's version (the lab's own)   TEST SKIP   RESET PREVIEW
## Nothing is spent, owned, counted or saved (play_lab's teams; Store.looks is never touched).

var cat_i := 0                # GOAL CELEBRATIONS first
var lv := 1
var bar_goal := false
var calm := false
var queue: Array = []         # levels still to play (COMPARE)
var skips := 0
var cheer := 0.0
var goal_run := false         # Goal Celebrations: a goal's show running
var crowd_t := -1.0           # Crowd Atmosphere's COMPARE: s until the next level
var crowd_btn: Button
var game_i := 0               # REGULAR, BIG, CONF, NCSA
var game_btn: Button
var cine = null               # a PregameIntro playing
var bc: BroadcastFx = null    # Broadcast Presentation's graphic
var rows_ui: Array = []       # the button rows
var schools: Array = []       # NEXT SCHOOL: all 30, made here
var school_i := 0
var cat_btn: Button
var goal_btn: Button
var motion_btn: Button
var board_st := MatchState.new()   # the SCOREBOARD preview's game: Q4, 1:12, 7-6 (nothing counted)

func lab_title() -> String:
	return "VISUAL UPGRADE TESTING"

func _ready() -> void:
	lab_ready(lab_title())
	use_career_teams()
	board_st.score = [7, 6]
	board_st.quarter = 4
	board_st.clock = 72.0
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
		next_school()
		if cat_id() == "crowd":
			_show_stands()
		_labels(), 90, "HomeSchool", "ghost")
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
	crowd_btn.text = "HOME: %s" % Colleges.short_name(us).to_upper()
	game_btn.text = "GAME: %s" % ["REGULAR", "BIG", "CONF", "NCSA"][game_i]
	var top := VisualUpgrades.top(cat_id())
	lv = mini(lv, top)
	for n in VisualUpgrades.MAX_LEVEL:
		var b: Button = find_child("Level%d" % (n + 1), true, false)
		if b != null:
			b.visible = n < top
			b.text = "LEVEL %d" % (n if cat_id() == "goal" else n + 1)   # (Goal Celebrations count from 0)
			UI.style_button(b, "primary" if n + 1 == lv else "normal")
	status = "%s LEVEL %d: %s" % [cat_btn.text, lv - 1 if cat_id() == "goal" else lv, String(VisualUpgrades.CATS[cat_i].tiers[lv - 1][0])]

func settled() -> void:
	if goal_run:
		goal_run = false
		if not queue.is_empty():
			lv = queue.pop_front()
			_score_goal()
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
	status = "LEVEL %d: %s" % [lv - 1 if cat_id() == "goal" else lv, String(VisualUpgrades.CATS[cat_i].tiers[lv - 1][0])]   # (Goal Celebrations count from 0)
	if d.is_empty():
		play.dev_goal(Geo.GOAL_Y - 0.6, 0.55)
	else:
		play.dev_goal(float(d.cross_y), float(d.height))

func _show_stands() -> void:
	new_play()
	paused = true
	status = "CROWD LEVEL %d: %s  %d%% FULL" % [lv, String(VisualUpgrades.cat("crowd").tiers[lv - 1][0]), roundi(CrowdArt.fill_of(lab_style()) * 100.0)]

## Plays the picked level. False if that category's effects don't exist yet.
func preview() -> bool:
	if not built():
		status = "%s: NOT BUILT YET" % cat_btn.text
		return false
	queue.clear()
	match cat_id():
		"goal", "broadcast", "scoreboard":
			_score_goal()
		"crowd":
			_show_stands()
		"pregame":
			_play_cine(lv)
	return true

## An entrance at level `l`: the match's own object, on the stage.
func _play_cine(l: int) -> void:
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

## Your dynasty's team at home and its rival (VisualUpgrades.preview_rival_id), as copies: their
## real names, colours, logos and players, nothing a preview does reaching the save. Read fresh
## each time the screen opens, so a new program or another save shows at once. Without a career
## (or a rival) the lab's own made-up teams stay.
func use_career_teams() -> void:
	var c: Career = Game.career
	var mine := VisualUpgrades.preview_team(c, c.school) if c != null else null
	var rival := VisualUpgrades.preview_team(c, VisualUpgrades.preview_rival_id(c))
	if mine == null or rival == null:
		return
	us = mine
	them = rival

## The next school's real colours and logo on the stage (of all 30), going on from the one shown.
func next_school() -> String:
	if schools.is_empty():
		schools = Career.new_setup(777).teams.values()
		var at: int = schools.map(func(s: PoloTeam): return s.id).find(us.id)
		if at >= 0:
			school_i = at
	school_i = (school_i + 1) % schools.size()
	us = schools[school_i]
	them = schools[(school_i + 7) % schools.size()]
	settled()
	status = Colleges.display_name(us.name).to_upper()
	return us.id

func lab_goal(who: PoloPlayer) -> void:
	if cat_id() == "broadcast":
		bc = BroadcastFx.new(lv, calm or HotFire.calm())
		bc.goal(who, us, 3, 5, "3-2")

func compare() -> bool:
	match cat_id():
		"goal", "broadcast", "scoreboard":
			queue = range(2, VisualUpgrades.top(cat_id()) + 1)
			lv = 1
			_score_goal()
		"pregame":
			queue = range(2, VisualUpgrades.top(cat_id()) + 1)
			_play_cine(1)
		"crowd":
			lv = 1
			crowd_t = 2.0
			_show_stands()
	return true

## TEST SKIP: an entrance (Pregame Presentation) cut short, back to the lab. False if there's
## none to skip (the other categories' previews have nothing to skip).
func test_skip() -> bool:
	if cine == null and (cat_id() != "pregame" or not preview()):
		return false
	cine.skip()
	cine = null
	queue.clear()
	skips += 1
	status = "SKIPPED: BACK TO THE LAB"
	return true

func reset_preview() -> void:
	queue.clear()
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
	return lv - 1 if cat_id() == "goal" else VisualUpgrades.CLASSIC   # (Goal Celebrations: LEVEL 0-3 on buttons 1-4)

func lab_style() -> Dictionary:
	if cat_id() != "crowd":
		return {}
	return CrowdArt.style(lv, us, them, false, lab_crowd(), calm or HotFire.calm(), 0, LAB_SEED)

const LAB_SEED := 7           # the lab's stands: the same seats every preview

func lab_crowd() -> float:
	return 0.6

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
				status = "DONE  (PREVIEW TO SEE IT AGAIN)"
		stage_cv.queue_redraw()
		return
	super(dt)

func _draw_stage(ci: Control) -> void:
	if cine != null:
		cine.draw(ci, ci.size)
		return
	super(ci)
	if bc != null:
		bc.draw(ci, ci.size, false, scratch)
	if cat_id() == "scoreboard":
		draw_board(ci, lv)

## The SCOREBOARD preview: level `l`'s board along the stage's top, the goal going up on it. The
## board and the shot clock on its left are centred together (the board alone, as in a match, would
## push the shot clock off a narrow stage's left edge); a stage too narrow for both side by side
## has the board centred and the shot clock tucked under its left end, never cut off.
const SC_ROOM := 40.0          # the widest shot clock (Premium's 34 + its shadow) and its gap
func draw_board(ci: Control, l: int) -> Rect2:
	var side := Scoreboard.width(l, us, them) + SC_ROOM + 4.0 <= ci.size.x
	var board := Hud.scoreboard(ci, ci.size.x + (SC_ROOM if side else 0.0), board_st, us, them, US_CAP, them.cap_against(US_CAP), them.trim_against(US_CAP), goal_show.board_fx(), l)
	var sc := play.shot_clock if play != null else 30.0
	if side:
		Scoreboard.shot_clock(ci, l, board, sc)
	else:
		# shot_clock() sits at the top beside the board it's given: give it one starting past the
		# shot clock's own width, and draw it a row below the real board
		var at := maxf(board.position.x, 2.0)
		ci.draw_set_transform(Vector2(0, board.end.y + 1.0))
		Scoreboard.shot_clock(ci, l, Rect2(at + SC_ROOM - 3.0, 0, 0, 0), sc)
		ci.draw_set_transform(Vector2.ZERO)
	return board
