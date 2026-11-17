extends "res://src/ui/screens/play_lab.gd"
## Developer Mode's SCOREBOARD VISUAL PREVIEW (Settings > Developer Mode): the Scoreboard upgrade's
## three tiers (Scoreboard) over a live possession you can play (aim, pass, shoot), the shot clock
## and the game clock running, every tier owned or not.
##   TIER 1 .. 3       switches the board at once: the play, the clocks and the score carry on
##   VIEW              LIVE (one board, over the play) or ALL TIERS (the three stacked, the same game)
##   HOME / AWAY       the next school (all 30, their real colours and logos), then two made-up clubs
##   SCORE / QTR / CLOCK   preset scores (two digits included), Q1..Q4 and the SHOOTOUT, clock values
##   GOAL HOME / GOAL AWAY   the board's goal animation (BIG: the tie / winner version); a goal you
##                     score in the pool plays it too
##   MATCHES           Developer Mode's override: every match this session shows the tier picked
##                     (Scoreboard.override), whatever is owned or worn; never saved, and gone when
##                     Developer Mode is turned off. In a match, the pause menu's BOARD button (or F8)
##                     switches it on the spot.
##   TEST MATCH        a quick match between HOME and AWAY with the tier on (the override)
## Nothing is spent, owned, counted or saved: Store.looks is never touched, the score is the lab's.

const SCORES := [[0, 0], [3, 2], [7, 7], [12, 11], [21, 19]]
const CLOCKS := [120.0, 72.0, 45.0, 9.0]
const GOAL_HOLD := 1.4         # s a test goal's animation runs before its point counts

var tier := 1
var all_view := false
var board_st := MatchState.new()
var teams: Array = []          # the 30 schools, then two made-up clubs (light: colours, names, logos)
var squads: Array = []         # the two made-up clubs: the players either side plays with
var home_i := 0
var away_i := 7
var score_i := 1
var clock_i := 1
var big := false
var lab_fx := {}               # a test goal going up: {side, add, t, col, big}
var pending_side := -1         # the pool's goal: its point counts once its show is done
var row_ui: Array = []
var tier_btns: Array = []
var view_btn: Button
var home_btn: Button
var away_btn: Button
var score_btn: Button
var qtr_btn: Button
var clock_btn: Button
var big_btn: Button
var match_btn: Button

func _ready() -> void:
	lab_ready("SCOREBOARD VISUAL PREVIEW")
	aims = true
	_teams()
	board_st.score = (SCORES[score_i] as Array).duplicate()
	board_st.clock = CLOCKS[clock_i]
	board_st.quarter = 2
	tier = Scoreboard.override if Scoreboard.override > 0 else Store.looks.worn("scoreboard")
	var r1 := _row()
	for n in Scoreboard.TOP:
		var l: int = n + 1
		var b := _btn("%d %s" % [l, Scoreboard.NAMES[n]], func(): set_tier(l), 74, "Tier%d" % l)
		tier_btns.append(b)
		r1.add_child(b)
	view_btn = _btn("", func():
		all_view = not all_view
		_labels(), 92, "View", "ghost")
	r1.add_child(view_btn)
	var r2 := _row()
	home_btn = _btn("", func(): next_team(0), 92, "Home", "ghost")
	r2.add_child(home_btn)
	away_btn = _btn("", func(): next_team(1), 92, "Away", "ghost")
	r2.add_child(away_btn)
	score_btn = _btn("", next_score, 72, "Score", "ghost")
	r2.add_child(score_btn)
	qtr_btn = _btn("", next_quarter, 58, "Quarter", "ghost")
	r2.add_child(qtr_btn)
	clock_btn = _btn("", next_clock, 70, "Clock", "ghost")
	r2.add_child(clock_btn)
	var r3 := _row()
	r3.add_child(_btn("GOAL HOME", func(): test_goal(0), 70, "GoalHome", "primary"))
	r3.add_child(_btn("GOAL AWAY", func(): test_goal(1), 70, "GoalAway", "primary"))
	big_btn = _btn("", func():
		big = not big
		_labels(), 64, "Big", "ghost")
	r3.add_child(big_btn)
	match_btn = _btn("", toggle_override, 118, "MatchOverride", "ghost")
	r3.add_child(match_btn)
	r3.add_child(_btn("TEST MATCH", test_match, 76, "TestMatch"))
	_labels()
	settled.call_deferred()

func _row() -> HBoxContainer:
	var r := UI.hbox(3)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(r)
	row_ui.append(r)
	return r

func _btn(text: String, cb: Callable, w: int, n: String, style := "normal") -> Button:
	var b := UI.button(text, cb, style, w, 18)
	b.name = n
	b.clip_text = true
	return b

## The 30 schools as the scoreboard sees them (their names, colours and logos) with a made-up
## club's roster to play with, then the two made-up clubs themselves (no school logo: their own).
func _teams() -> void:
	squads = [League.make_team(2, 1), League.make_team(3, 1)]
	for i in Colleges.SCHOOLS.size():
		var s: Dictionary = Colleges.SCHOOLS[i]
		var t := PoloTeam.new()
		t.id = String(s.short)
		t.name = String(s.name)
		t.mascot = String(s.mascot)
		t.c1 = Color(String(s.c1))
		t.c2 = Color(String(s.c2))
		t.conf = String(s.conf)
		teams.append(t)
	teams.append_array(squads)
	_use_teams()

## HOME and AWAY in the pool: a school plays with a made-up club's players, never the same men as
## the other side.
func _use_teams() -> void:
	us = teams[home_i]
	them = teams[away_i]
	if not us in squads:
		us.roster = (squads[1] if them == squads[0] else squads[0]).roster
	if not them in squads:
		them.roster = (squads[0] if us == squads[1] else squads[1]).roster

func home() -> PoloTeam:
	return teams[home_i]

func away() -> PoloTeam:
	return teams[away_i]

func _labels() -> void:
	for n in tier_btns.size():
		UI.style_button(tier_btns[n], "primary" if n + 1 == tier else "normal")
	view_btn.text = "VIEW: %s" % ("ALL TIERS" if all_view else "LIVE")
	home_btn.text = "HOME: %s" % Scoreboard.abbr(home())
	away_btn.text = "AWAY: %s" % Scoreboard.abbr(away())
	score_btn.text = "SCORE: %d-%d" % [board_st.score[0], board_st.score[1]]
	qtr_btn.text = "SHOOTOUT" if board_st.in_shootout else "QTR: Q%d" % board_st.quarter
	clock_btn.text = "CLOCK: %s" % board_st.clock_text()
	big_btn.text = "BIG: %s" % ("ON" if big else "OFF")
	match_btn.text = "MATCHES: %s" % ("TIER %d" % Scoreboard.override if Scoreboard.override > 0 else "OFF")
	status = "TIER %d %s  -  %s vs %s  -  MATCH OVERRIDE %s" % [tier, Scoreboard.NAMES[tier - 1],
		Colleges.short_name(home()).to_upper(), Colleges.short_name(away()).to_upper(), "ON" if Scoreboard.override > 0 else "OFF"]

## Switches the board; nothing else changes (the play, the clocks, the score, a goal going up).
func set_tier(n: int) -> void:
	tier = clampi(n, 1, Scoreboard.TOP)
	if Scoreboard.override > 0:
		Scoreboard.override = tier
	_labels()

func next_team(side: int) -> void:
	if side == 0:
		home_i = (home_i + 1) % teams.size()
		if home_i == away_i:
			home_i = (home_i + 1) % teams.size()
	else:
		away_i = (away_i + 1) % teams.size()
		if away_i == home_i:
			away_i = (away_i + 1) % teams.size()
	_use_teams()
	settled()
	_labels()

func next_score() -> void:
	score_i = (score_i + 1) % SCORES.size()
	board_st.score = (SCORES[score_i] as Array).duplicate()
	_labels()

## Q1 .. Q4, then the shootout (3-2 in penalties), then back to Q1.
func next_quarter() -> void:
	if board_st.in_shootout:
		board_st.in_shootout = false
		board_st.quarter = 1
	elif board_st.quarter >= MatchState.QUARTERS:
		board_st.in_shootout = true
		board_st.shootout = [3, 2]
	else:
		board_st.quarter += 1
	_labels()

func next_clock() -> void:
	clock_i = (clock_i + 1) % CLOCKS.size()
	board_st.clock = CLOCKS[clock_i]
	_labels()

## The board's goal animation for `side` (the shootout's score in a shootout); the point counts
## once it's done, as in a match.
func test_goal(side: int) -> void:
	_commit()
	lab_fx = {"side": side, "add": 1, "t": 0.0, "col": US_CAP if side == 0 else them.cap_against(US_CAP), "big": big}

func _commit() -> void:
	if lab_fx.is_empty():
		return
	var side := int(lab_fx.side)
	if board_st.in_shootout:
		board_st.shootout[side] += 1
	else:
		board_st.score[side] += 1
	lab_fx = {}
	_labels()

func toggle_override() -> void:
	Scoreboard.override = 0 if Scoreboard.override > 0 else tier
	_labels()

## A quick match between HOME and AWAY, the tier on for it (the session's override).
func test_match() -> void:
	Scoreboard.override = tier
	Game.match_cfg = {"us": home(), "them": away(), "seed": randi(), "minutes": float(MatchState.quarter_min_for(false))}
	Game.goto("match", Game.match_cfg)

## The board's fx now: the pool's goal (its show's own), else a test goal.
func board_fx() -> Dictionary:
	var fx := goal_show.board_fx()
	return fx if not fx.is_empty() else lab_fx

# ------------------------------------------------------------------ the live play
## A fresh possession, live: play it, or let the shot clock run out.
func settled() -> void:
	if pending_side >= 0:
		board_st.score[pending_side] += 1
		pending_side = -1
		_labels()
	new_play()
	paused = false

func lab_goal(_who: PoloPlayer) -> void:
	if not board_st.in_shootout:
		pending_side = 0

func lab_tick(dt: float) -> void:
	if not lab_fx.is_empty():
		lab_fx.t = float(lab_fx.t) + dt
		if float(lab_fx.t) > GOAL_HOLD:
			_commit()
	# the game clock runs while the ball's live, as in a match; a quarter's end rolls on to the next
	if play != null and not paused and not play.over and not goal_show.active() and not board_st.in_shootout:
		board_st.clock -= dt * MatchState.CLOCK_SPEED
		if board_st.clock <= 0.0:
			board_st.clock = board_st.quarter_len
			board_st.quarter = board_st.quarter % MatchState.QUARTERS + 1
			_labels()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				set_tier(event.keycode - KEY_0)
			KEY_G:
				test_goal(0)

# ------------------------------------------------------------------ drawing
func _draw_stage(ci: Control) -> void:
	super(ci)
	var sc := play.shot_clock if play != null else Play.SHOT_CLOCK
	if not all_view:
		var b := Hud.scoreboard(ci, ci.size.x, board_st, home(), away(), US_CAP, away().cap_against(US_CAP), away().trim_against(US_CAP), board_fx(), tier)
		Scoreboard.shot_clock(ci, tier, b, sc)
		return
	# ALL TIERS: the three, stacked over a darkened pool, the same game on each
	ci.draw_rect(Rect2(0, 0, ci.size.x, minf(ci.size.y - 12.0, Scoreboard.TOP * 32.0 + 2.0)), Color(0.02, 0.04, 0.1, 0.7))
	for n in Scoreboard.TOP:
		var oy := float(n) * 32.0
		ci.draw_set_transform(Vector2(0, oy))
		var b := Hud.scoreboard(ci, ci.size.x, board_st, home(), away(), US_CAP, away().cap_against(US_CAP), away().trim_against(US_CAP), board_fx(), n + 1)
		Scoreboard.shot_clock(ci, n + 1, b, sc)
		UI.text(ci, Vector2(3, 12), str(n + 1), 8, UI.GOLD if n + 1 == tier else Hud.DIM, "caps")
		ci.draw_set_transform(Vector2.ZERO)
