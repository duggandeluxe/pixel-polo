extends Control
## The match: shows MatchFlow's phases, runs both teams' attacks in real time and reads touches.

const US_CAP := Color("f2f2e9")
const SLOWMO := 0.6            # the pool slows a little while you aim
const END_HOLD := 1.5          # seconds the result banner stays up
const LINE_EVERY := 0.6        # their-ball card: one line every this many seconds

var flow: MatchFlow
var view := PoolView.new()
var mcam := ManUpCam.new()   # the 6 on 5 push in and its impact shake (the world layer only)
var aim := AimGuide.new()
var stick := ShotStick.new()   # the shooting stick on the left: the only way you shoot (AimGuide.stick_at)
var calls := CallStrip.new()   # DRIVE▾, your play call
var fbar := FormationBar.new() # your defence's formation, along the bottom while they attack
var halftime := HalftimePanel.new()   # the halftime break's MID-GAME ADJUSTMENT
var sprint: Sprint = null
var canvas: Control
var t := 0.0
var excite := 0.0
var paused := false
var autoplay := false          # tests: the bot plays your attacks
var bot_rng := RandomNumberGenerator.new()
var bot_think := 0.0

var last_phase := -1
var last_play: Play = null
var end_timer := -1.0          # counting down after a possession ends
var sprint_end := -1.0
var card_t := 0.0
var card_shown := 0
var banner := EventBanner.new()   # every gameplay callout (FOUL!, WIDE!...), one at a time
var goal_show := GoalShow.new()   # a goal's moment: GOAL!, the scorer, the board going up (GoalShow)
var bar_show := BarHit.new()      # ...in off the frame first: BAR-IN! / BAR-DOWN! (BarHit)
var pause_rect := Rect2()
var buttons: Array = []        # final-card buttons: [Rect2, label, Callable]
var results: ResultsPanel = null   # the full-time panel
var pool: PoolDef              # the venue: the home team's pool
var crowd := 0.8               # how full the stands are
var career := false            # a career game: the result goes back to Game.career
var handed_over := false       # the result has gone to the career
var level := Difficulty.MEDIUM   # difficulty this match is played at (Difficulty): fixed at the start, never moved during it
var duel_bodies: Array[Swimmer] = []   # their shot: your keeper, the shooter, a couple more
var duel_end := -1.0           # counting down after the duel's result
var duel_start := 0.0          # when the duel scene came up
var duel_ball: Ball = null     # a shootout goal against you, in your net after the duel
const DUEL_TAP_GRACE := 0.3
var duel_skill := 0.7          # autoplay: how good the bot keeper is
var dive_note := ""            # TOO EARLY / TOO LATE under the GOAL banner (your mistimed dive)
var dive_note_t := 0.0
var roll_note := {}            # the last roll-out's notice (Hud.roll_note), from roll_note_t
var roll_note_t := -100.0
var intro: PregameIntro = null # the pregame entrance (PregameIntro): the match waits, untouched, until it's done
var intros_done := 0           # (tests: the hand-over happens once)
var rec: ReplayBuffer = null   # the last few seconds on the water (null: replays off for this match)
var replay: ReplayShow = null  # a goal's replay: the match waits at the stoppage until it's over
var replay_then := Callable()  # ...and this carries on, once
var replay_goal := false       # a goal's been scored this possession: one replay when its show ends
var replay_who: PoloPlayer = null   # ...by him
var replay_side := 0                # ...for this side
var replays_done := 0          # (tests)
var replay_who_seen: PoloPlayer = null   # the scorer of the replay on now (tests)
var replay_level := 1          # what a goal's replay is (ReplayShow.level_for)
var bot_sprint_t := 0.0        # autoplay: seconds since the sprint's whistle
var goal_fx := GoalFx.new()    # the Goal Celebrations level over the goal show
var broadcast := BroadcastFx.new()   # the Broadcast Presentation level's graphics
var victory: VictoryShow = null      # your win, before the full-time panel
var victories_done := 0        # (tests)
var victory_on := false        # this match shows it
var victory_title := ""        # "conf" / "nat": this game is that final
var victory_big := false
var stand_style := {}          # the Crowd Atmosphere level (CrowdArt.style; {}: the plain crowd)

func setup(params: Dictionary) -> void:
	var cfg: Dictionary = params if not params.is_empty() else Game.match_cfg
	autoplay = cfg.get("autoplay", false)
	career = cfg.get("career", false) and Game.career != null
	level = float(cfg.get("level", Difficulty.level_for(career)))
	flow = MatchFlow.new(cfg.us, cfg.them, int(cfg.get("seed", randi())), float(cfg.get("minutes", MatchState.QUARTER_MIN)), level)
	flow.home = cfg.get("home", true)
	bot_rng.seed = 99
	pool = Pools.get_def(String(cfg.get("pool", Pools.DEFAULT_ID)))
	if career:
		var c := Game.career
		crowd = 0.3 + ((c.team().prestige if cfg.get("home", true) else flow.them.prestige) / 100.0) * 0.7   # (the stands: the home school's following)
		flow.set_gameplan(c.gameplan)   # Coaching's drop: this match's copy (the halftime decision never goes back)
		crowd = CrowdArt.attendance(crowd, int(cfg.get("importance", 0)))   # (a bigger game, a fuller pool: for everyone, whatever they own)
	elif cfg.has("drop"):
		flow.set_gameplan(int(cfg.drop))
	if autoplay:
		flow.auto_keeper = duel_skill
	# the pregame entrance: a match you play (never a bot's, a test's unless asked, or the tutorial,
	# which has its own setup); the game's designation from the schedule
	var home_side: PoloTeam = flow.us if bool(cfg.get("home", true)) else flow.them
	stand_style = CrowdArt.style(Store.looks.worn("crowd"), home_side, flow.them if home_side == flow.us else flow.us, bool(cfg.get("neutral", false)), crowd, HotFire.calm(),
		int(cfg.get("importance", 0)))
	broadcast = BroadcastFx.new(Store.looks.worn("broadcast"), HotFire.calm())
	victory_on = bool(cfg.get("victory", not autoplay and not Game.test_mode))
	victory_title = String(cfg.get("title", ""))
	victory_big = int(cfg.get("importance", 0)) >= 1
	# instant replay: recorded for a match you play once it's unlocked and switched on. Locked,
	# nothing is recorded and a goal goes straight on. ReplayShow's levels: 2 the plain replay, 3
	# the cinematic one; which is the owner's presentation setting (Settings "replay_style")
	replay_level = int(cfg.get("replay_level", ReplayShow.level_for(Store.looks.worn("replay"), String(Game.settings.get("replay_style", "cinematic")))))
	if bool(cfg.get("replay", not autoplay and not Game.test_mode)) and bool(Game.settings.get("auto_replay", true)) and replay_level >= 2:
		rec = ReplayBuffer.new()
	if bool(cfg.get("intro", not autoplay and not Game.test_mode)):
		intro = PregameIntro.new(flow.us, flow.them, bool(cfg.get("home", true)), String(cfg.get("stage", "")),
			String(cfg.get("venue", "")), pool)
		intro.crowd = crowd
		intro.style = stand_style
		intro.set_level(Store.looks.worn("pregame"))
		intro.paint_body = func(ci: CanvasItem, v: PoolView, sw: Swimmer): PoolArt.draw_body(ci, v, sw, _cap(sw), _trim(sw), _design(sw))

func _ready() -> void:
	canvas = UI.canvas(0, 0, _draw_all)
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.music("race")
	Sfx.crowd(0.35)

# ------------------------------------------------------------------ loop
func _process(dt: float) -> void:
	if paused:
		return
	if intro != null:
		_tick_intro(dt)
		return
	if replay != null:
		_tick_replay(dt)
		return
	if victory != null:
		victory.step(dt)
		if victory.done:
			_end_victory()
		canvas.queue_redraw()
		return
	t += dt
	excite = maxf(0.0, excite - dt * 0.5)
	view.width = get_viewport_rect().size.x
	view.height = get_viewport_rect().size.y
	if flow.phase != last_phase or flow.play != last_play:
		_enter_phase()
	match flow.phase:
		MatchFlow.Phase.SPRINT:
			_tick_sprint(dt)
		MatchFlow.Phase.ATTACK:
			_tick_attack(dt)
		MatchFlow.Phase.DEFENSE:
			_tick_defense(dt)
		MatchFlow.Phase.SHOOTOUT_THEM:
			_tick_card(dt)
			if flow.play != null:
				flow.play.step(dt)
		MatchFlow.Phase.THEIR_SHOT:
			_tick_duel(dt)
	stick.layout(get_viewport_rect().size, _insets())
	stick.step(dt, _stick_ready(flow.play), aim.stick)
	banner.step(dt)
	goal_show.step(dt, view)
	goal_fx.tick(view)
	broadcast.step(dt)
	bar_show.step(dt)
	if results != null and flow.phase == MatchFlow.Phase.FINAL:
		results.step(dt)
	if rec != null and flow.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE, MatchFlow.Phase.THEIR_SHOT]:
		_record(dt)
	_tick_man_up_cam(dt)
	canvas.queue_redraw()

# ------------------------------------------------------------------ the 6 on 5 camera
## Is it 6 on 5 (either way) on the water right now?
func _man_up_on() -> bool:
	var p := flow.play
	return p != null and flow.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE] and p.man_up > 0.0 and not p.over

## The push in (ManUpCam): about the 4-2 while it's on, then wherever it was as it eases out.
func _tick_man_up_cam(dt: float) -> void:
	var on := _man_up_on()
	if on:
		mcam.pivot = _man_up_pivot(flow.play)
	mcam.step(dt, on)
	view.cine = mcam.xform()

## The screen point of the middle of the attack's 4-2 (and so of its goal's side of the pool),
## kept inside the pool's part of the screen.
func _man_up_pivot(p: Play) -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for a in p.attackers:
		if not a.out:
			lo = lo.min(a.pos)
			hi = hi.max(a.pos)
	if lo.x == INF:
		return Vector2(view.width * 0.5, (view.height + PoolView.HUD_H) * 0.5)
	var s := view.to_screen((lo + hi) * 0.5)
	return Vector2(clampf(s.x, 0.0, view.width), clampf(s.y, PoolView.HUD_H, view.height))

# ------------------------------------------------------------------ instant replay
## What's on the water now into the recorder (it only reads).
func _record(dt: float) -> void:
	var bodies: Array = duel_bodies if flow.phase == MatchFlow.Phase.THEIR_SHOT else (flow.play.bodies() if flow.play != null else [])
	if bodies.is_empty():
		return
	rec.tick(dt * goal_show.time_scale() * bar_show.play_scale(), bodies, _record_ball(), view)

func _record_ball() -> Dictionary:
	if flow.phase == MatchFlow.Phase.THEIR_SHOT and flow.duel != null:
		var d := flow.duel
		var b: Ball = duel_ball
		var at := Vector3(b.pos.x, b.pos.y, b.z) if b != null else Vector3(d.ball_pos().x, d.ball_pos().y, d.ball_z())
		var flying := d.state == KeeperDuel.State.FLIGHT
		return {"at": at, "shot": flying, "dir": Vector2(d.goal_x, d.cross_y) - d.from,
			"power": PoolArt.shooter_power(d.shooter_pace * 100.0), "fire": Attributes.hot_stars(d.by), "flown": 1.0, "net": _net()}
	return ReplayBuffer.ball_of(flow.play.ball, _net())

## The goal's show is over: its replay if there's one to show, then `then` (the goal's counted
## there, as it always was). No replay: straight on.
func _after_show(then: Callable) -> void:
	var scored := replay_goal
	replay_goal = false
	var who := replay_who
	var side := replay_side
	_end_goal_show()
	if not scored or rec == null or flow.state.in_shootout:
		then.call()
		return
	var cl := rec.clip()
	rec.clear()
	if cl.is_empty():
		then.call()
		return
	replay = ReplayShow.new(cl, replay_level, HotFire.calm())
	replay_who_seen = who
	replay.pool = pool
	replay.crowd = crowd
	replay.style = stand_style
	replay.who = who.short_name() if who != null else ""
	replay.team = Colleges.short_name(flow.us if side == 0 else flow.them).to_upper()
	replay.col = _us_cap() if side == 0 else flow.them.cap_against(_us_cap())
	replay.paint_body = func(ci: CanvasItem, v: PoolView, sw: Swimmer): PoolArt.draw_body(ci, v, sw, _cap(sw), _trim(sw), _design(sw))
	replay_then = then
	Sfx.play("card", 1.0, -8.0)

func _tick_replay(dt: float) -> void:
	replay.step(dt)
	if replay.done:
		_end_replay()
	canvas.queue_redraw()

## The replay's over or skipped: the match carries on, once.
func _end_replay() -> void:
	if replay == null:
		return
	replay = null
	replays_done += 1
	var then := replay_then
	replay_then = Callable()
	if then.is_valid():
		then.call()

## The win's presentation is over (or skipped): the full-time panel, as ever. Once.
func _end_victory() -> void:
	if victory == null:
		return
	victory = null
	victories_done += 1

## The pregame entrance's frame: only it moves (no clock, no shot clock, no play); its end hands
## the match over, once.
func _tick_intro(dt: float) -> void:
	view.width = get_viewport_rect().size.x
	view.height = get_viewport_rect().size.y
	if intro.end_view == null:
		# the camera the game opens on (the sprint's): the reveal comes down onto it
		var ev := PoolView.new()
		ev.width = view.width
		ev.height = view.height
		ev.snap_to(Sprint.new(flow.us, flow.them, 0.0).focus())
		intro.end_view = ev
	intro.step(dt)
	if intro.done:
		_end_intro()
	canvas.queue_redraw()

func _end_intro() -> void:
	if intro == null:
		return
	intro = null
	intros_done += 1
	Sfx.crowd(0.35)

func _enter_phase() -> void:
	last_phase = flow.phase
	last_play = flow.play
	if flow.play != null:
		flow.play.keeper.cheer_style = ""   # (a keeper's celebration ends with the stoppage)
	aim.cancel()
	calls.open = false
	card_t = 0.0
	card_shown = 0
	end_timer = -1.0
	banner.clear()
	_end_goal_show()
	bar_show.clear()
	if flow.play != null:
		flow.play.bar_fx = true
		flow.play.bar_mode = BarHit.mode_for(bool(Game.settings.get("dev_mode", false)) and not autoplay)
	view.mirror = flow.phase == MatchFlow.Phase.DEFENSE   # they attack your goal, on the left
	view.wide(false)   # (a test may have pulled the camera back to the whole pool)
	match flow.phase:
		MatchFlow.Phase.SPRINT:
			sprint = Sprint.new(flow.us, flow.them, flow.their_sprint_speed())
			sprint_end = -1.0
			view.snap_to(sprint.focus())
		MatchFlow.Phase.ATTACK:
			view.snap_to(view.attack_frame(flow.play))
			match flow.play.kind:
				Play.Kind.COUNTER:
					banner.show(_break_text("BREAK!", flow.play), EventBanner.YELLOW)
				Play.Kind.PENALTY:
					if flow.state.in_shootout:   # (a penalty in play was already called: PENALTY!)
						banner.show("SHOOTOUT!", EventBanner.YELLOW)
					Sfx.play("whistle")
		MatchFlow.Phase.DEFENSE:
			view.snap_to(PoolView.attack_focus(flow.play.ball.pos))
			match flow.play.kind:
				Play.Kind.COUNTER:
					banner.show(_break_text("GET BACK!", flow.play), EventBanner.RED)
				Play.Kind.PENALTY:
					Sfx.play("whistle")
		MatchFlow.Phase.SHOOTOUT_THEM:
			Sfx.play("card")
			_card_sound()
		MatchFlow.Phase.THEIR_SHOT:
			_start_duel()
		MatchFlow.Phase.BREAK:
			if flow.state.is_last_quarter():
				flow.break_done()   # no card after the 4th: the results (or the shootout) come straight up
			else:
				Sfx.play("bell")
		MatchFlow.Phase.FINAL:
			Sfx.crowd(0.0)
			results = ResultsPanel.new().setup(flow.state,
				Game.career.records_after(flow.state.winner() == 0) if career and Game.career != null else {})
			if not autoplay:
				# (a completed game: the only time DYNAMIC moves)
				Difficulty.after_game(career, flow.state.score[0], flow.state.score[1], flow.us, flow.them)
			var won := flow.state.winner() == 0
			Sfx.music("victory" if won else "")
			if won and victory_on:
				victory = VictoryShow.new(flow.us, Store.looks.worn("victory"), victory_title, victory_big, HotFire.calm())
				victory.pool = pool
				victory.crowd = crowd
				victory.style = stand_style
				victory.score = [int(flow.state.score[0]), int(flow.state.score[1])]
				victory.paint_body = func(ci: CanvasItem, v: PoolView, sw: Swimmer): PoolArt.draw_body(ci, v, sw, _cap(sw), _trim(sw), _design(sw))
			Sfx.play("cheer" if won else "miss")

## A counter's callout with its numbers: "3 ON 2 BREAK!", "GET BACK! 2 ON 1".
static func _break_text(word: String, p: Play) -> String:
	var n := p.break_n
	if n.x <= 0:
		return "COUNTERATTACK!" if word == "BREAK!" else word
	var nums := "%d ON %d" % [n.x, n.y]
	return "%s %s" % [nums, word] if word == "BREAK!" else "%s %s" % [word, nums]

func _tick_sprint(dt: float) -> void:
	var was := sprint.whistled
	sprint.step(dt)
	view.follow(sprint.focus(), dt)
	if sprint.whistled and not was:
		Sfx.play("whistle")
	# (the bot's tapping keeps its own time from the sprint's start: a presentation before it, or a
	# frame's real length, must not be able to change who wins it)
	bot_sprint_t = bot_sprint_t + dt if sprint.started() else 0.0
	if autoplay and sprint.started() and int(bot_sprint_t * 12.0) % 2 == 0:
		sprint.tap()
	if sprint.done and sprint_end < 0.0:
		sprint_end = 1.0
		banner.show("YOUR BALL!" if sprint.we_won else "THEIR BALL!", EventBanner.YELLOW if sprint.we_won else EventBanner.WHITE)
		Sfx.play("good" if sprint.we_won else "miss")
	if sprint_end >= 0.0:
		sprint_end -= dt
		if sprint_end < 0.0:
			flow.sprint_done(sprint.we_won)

func _tick_attack(dt: float) -> void:
	var p := flow.play
	var scale := SLOWMO if ((aim.active and aim.stick and p.can_throw()) or calls.open) else 1.0
	if autoplay:
		_bot(dt)
	else:
		_stick_aim(p)
		p.raise_ball(aim.active and aim.stick and aim.long_enough() and p.can_throw() and p.shooting_pull(aim.target(p.holder)))
	flow.tick_attack(dt * scale * goal_show.time_scale() * bar_show.play_scale())
	_handle_events()
	_follow(view.attack_frame(p), dt)
	if end_timer >= 0.0:
		end_timer -= dt
		if end_timer < 0.0:
			_after_show(flow.attack_done)   # (the show ends before the goal's counted: the board mustn't show it twice)

## Their attack: the AI defends and you keep goal when they shoot. Autoplay: the bot keeper.
func _tick_defense(dt: float) -> void:
	var p := flow.play
	flow.tick_defense(dt * goal_show.time_scale() * bar_show.play_scale())
	_handle_events()
	# (6 on 5: the whole 4-2 framed, as on your own power play, so the push in keeps all of it)
	_follow(view.attack_frame(p) if _man_up_on() else PoolView.attack_focus(p.ball.pos), dt)
	if end_timer >= 0.0:
		end_timer -= dt
		if end_timer < 0.0:
			_after_show(flow.defense_done)

## The camera on `focus`, or on the goal while a goal's being celebrated (GoalShow).
func _follow(focus: Vector2, dt: float) -> void:
	if goal_show.active():
		view.zoom_to = goal_show.zoom()
		focus = goal_show.focus()
	view.follow(focus, dt)

func _bot(dt: float) -> void:
	bot_think -= dt
	if bot_think > 0.0:
		return
	bot_think = PlayBot.THINK_EVERY
	var d := PlayBot.think(flow.play, bot_rng)
	if not d.is_empty():
		flow.play.throw(d.target, d.power)

func _tick_card(dt: float) -> void:
	card_t += dt
	var lines: Array = flow.opp.get("lines", [])
	var want := mini(lines.size(), int(card_t / LINE_EVERY) + 1)
	if want > card_shown:
		card_shown = want
		if card_shown == lines.size():
			_card_sound()
	var hold := 0.5 if flow.opp.get("shot", false) else (1.0 if autoplay else 1.4)
	if card_t > lines.size() * LINE_EVERY + hold:
		flow.their_ball_done()

func _card_sound() -> void:
	if card_shown < flow.opp.get("lines", []).size():
		return
	match String(flow.opp.get("tone", "")):
		"good":
			Sfx.play("good")
		"bad":
			Sfx.play("miss")

# ------------------------------------------------------------------ events
func _handle_events() -> void:
	var defending := flow.phase == MatchFlow.Phase.DEFENSE
	for e in flow.events:
		match String(e.k):
			"pass":
				Sfx.play("stroke", 1.3, -6.0)
			"catch":
				Sfx.play("touch", 1.1, -8.0)
			"drive":
				if not defending:
					banner.show("DRIVE %s!" % CallStrip.LABELS.get(e.side, ""), EventBanner.YELLOW)
			"windup":
				banner.show("HE'S SHOOTING!", EventBanner.RED)
			"ball_down":
				Sfx.play("splash", 1.6, -12.0)
			"shot":
				if float(e.get("catch_shoot", 0.0)) > 0.0:
					Sfx.play("splash", 0.9, 2.5)   # a catch and shoot: a touch heavier
					Game.vibrate(22)
				else:
					Sfx.play("splash")
					Game.vibrate(15)
			"save":
				Sfx.play("gasp")
			"rebound":
				Sfx.play("turn")
				_rebound(String(e.text))
			"block":
				Sfx.play("turn")
				Game.vibrate(20)
				banner.event("block")
			"foul":
				Sfx.play("whistle", 1.15, -5.0)
				banner.event("foul")
			"tip":
				Sfx.play("turn")
				Game.vibrate(12)
				banner.show("TIPPED!")
			"exclusion":
				Sfx.play("whistle")
				banner.event("exclusion")
				mcam.push()   # the camera pushes in on the power play, with its impact shake
			"even":
				banner.show("6 ON 6")
			"foul_trouble":
				if int(e.side) == 0:
					banner.show("FOUL TROUBLE!", EventBanner.YELLOW)
			"rolled":
				_rolled(e)
			"net":
				_net_hit(not defending)
			"end":
				_on_play_end(e)
	flow.events.clear()

## A player ROLLED (three personal fouls): the notice, with his replacement when he's yours.
func _rolled(e: Dictionary) -> void:
	var p: PoloPlayer = e.p
	var mine := int(e.side) == 0
	var who := "%s  -  %s" % [p.short_name().to_upper(), p.pos_long().to_upper()]
	var lines: Array = [who, "3 PERSONAL FOULS"]
	if mine:
		var sub: PoloPlayer = e.get("sub")
		lines.append("OUT FOR THE REMAINDER OF THE GAME")
		lines.append("REPLACEMENT: %s" % (sub.short_name().to_upper() if sub != null else "NONE: PLAYING SHORT"))
	roll_note = {"title": "PLAYER ROLLED!" if mine else "OPPONENT ROLLED!", "lines": lines}
	roll_note_t = t
	banner.show("ROLLED!", EventBanner.RED)
	Sfx.play("whistle")

func _on_play_end(e: Dictionary) -> void:
	var r := flow.play.result
	end_timer = END_HOLD
	if flow.phase == MatchFlow.Phase.DEFENSE:
		_defense_end(String(e.outcome), r)
		return
	match String(e.outcome):
		"goal":
			_play_goal(0, r)
			end_timer = goal_show.total()
		"save":
			banner.event("save")
			broadcast.save(flow.play.keeper.player, flow.them, int(flow.state.saves[1]))
		"miss":
			banner.show("WIDE!")
			Sfx.play("miss")
		"steal", "turnover":
			if _is_steal(String(e.outcome), r):
				banner.event("steal")
			else:
				banner.event("turnover")
			Sfx.play("error")
		"shotclock":
			banner.show("SHOT CLOCK!", EventBanner.RED)
			Sfx.play("dq")
		"penalty":
			banner.event("penalty")
			Sfx.play("whistle")
		"buzzer":
			banner.show("BUZZER!")
			Sfx.play("bell")

## Their possession is over: the banner, from your side of it.
func _defense_end(outcome: String, r: Dictionary) -> void:
	match outcome:
		"goal":
			_dive_note(flow.last_timing)
			Sfx.play("miss")
			_play_goal(1, r)
			end_timer = goal_show.total()
		"save":
			banner.event("save")
			broadcast.save(flow.play.keeper.player, flow.us, int(flow.state.saves[0]))
			Sfx.play("cheer")
			Sfx.play("perfect")
			Game.vibrate(30)
			excite = 0.8
		"miss":
			banner.show("WIDE!")
			Sfx.play("good")
		"steal":
			if _is_steal(outcome, r):
				banner.event("steal")
			else:
				banner.event("turnover")
			Sfx.play("cheer")
			Game.vibrate(25)
			excite = 0.6
		"turnover":
			banner.event("turnover")
			Sfx.play("good")
		"shotclock":
			banner.show("SHOT CLOCK!", EventBanner.RED)
			Sfx.play("good")
		"penalty":
			banner.event("penalty")
			Sfx.play("whistle")
		"buzzer":
			banner.show("BUZZER!")
			Sfx.play("bell")

## A goal in play, `side` 0 yours, 1 theirs (the play's "end"): the goal show, with the
## scorer and his teammates from the play and the keeper he beat. It isn't counted here:
## attack_done / defense_done do that, once, when the show's over.
func _play_goal(side: int, r: Dictionary) -> void:
	var p := flow.play
	var who: PoloPlayer = r.get("scorer")
	var pre := 0.0
	if p.ball.bar_on() and p.ball.in_net():
		bar_show.start(p.ball, view)   # off the frame: BAR-IN! / BAR-DOWN! first, then the show
		pre = BarHit.PRE
	_start_goal(side, who, Vector2(Geo.GOAL_X, p.ball.pos.y), false, pre)
	var hero: Swimmer = p.ball.shooter
	if hero == null or hero.player != who:
		hero = null
		for s in p.bodies():
			if s.player == who and not s.keeper:
				hero = s
	goal_show.cast(hero, [] if p.shootout else p.attackers, p.keeper)
	_celebrate()

## Any goal: the banner makes way and the show starts (GoalShow). `decides`: their shootout
## penalty that wins it.
func _start_goal(side: int, who: PoloPlayer, at: Vector2, decides: bool = false, pre: float = 0.0) -> void:
	banner.clear()
	var team := flow.us if side == 0 else flow.them
	var col := _us_cap() if side == 0 else flow.them.cap_against(_us_cap())
	goal_show.start(side, who, flow.state, Colleges.short_name(team).to_upper(), col, at, decides, pre)
	replay_goal = true
	replay_who = who
	replay_side = side
	goal_fx.start(Store.looks.worn("goal"), goal_show, team.c1, team.c2, HotFire.calm())
	var sc: Array = flow.state.score.duplicate()
	sc[side] = int(sc[side]) + 1
	broadcast.goal(who, team, goal_show.goals_today, (flow.state.shot_by[side] as Array).count(who), "%d-%d" % [int(sc[0]), int(sc[1])])
	if goal_fx.level >= 3 and team == _home_team():
		excite = GoalFx.EXCITE[goal_fx.level - 1]   # (a louder crowd for the home side's goal)
	excite = maxf(excite, 1.0) if side == 0 else excite

## The ball's in play and something's being controlled: broadcast graphics stay off the screen.
func _live() -> bool:
	if goal_show.active():
		return false
	if flow.phase == MatchFlow.Phase.THEIR_SHOT:
		return flow.duel != null and not flow.duel.done()
	return flow.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE] and flow.play != null and not flow.play.over

## This goal's celebration: the free poses and every enabled pack (Celebrations: art only).
func _celebrate() -> void:
	Celebrations.apply(goal_show, Celebrations.pick(int(flow.state.score[0]) + int(flow.state.score[1])))

func _home_team() -> PoloTeam:
	return flow.us if flow.home else flow.them

## The show's over (or skipped, or the phase moved on): the bodies and the camera back to normal.
func _end_goal_show() -> void:
	goal_fx.clear()
	bar_show.clear()
	if not goal_show.active():
		return
	goal_show.clear()
	view.zoom_to = 1.0
	view.zoom = 1.0

## A tap during a goal's show, once the ball's in: straight on to what's next (the goal's counted
## then, once, as it always is).
func _skip_goal() -> bool:
	if not goal_show.can_skip():
		return false
	if flow.phase == MatchFlow.Phase.THEIR_SHOT:
		if duel_end <= 0.0:
			return false
		duel_end = 0.0
	else:
		if end_timer <= 0.0:
			return false
		end_timer = 0.0
	Sfx.play("click")
	return true

## A loose ball off the keeper or the woodwork: a parry is a save.
func _rebound(text: String) -> void:
	if text == "PARRIED!":
		banner.event("save")
	else:
		banner.show(text)

## A real steal, the way the box score counts it (MatchState.is_steal).
func _is_steal(outcome: String, r: Dictionary) -> bool:
	return MatchState.is_steal(outcome, r)


# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if paused:
		return
	if intro != null:
		# any tap, click or key skips the entrance (the match then starts, once)
		if (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
			intro.skip()
			_end_intro()
			get_viewport().set_input_as_handled()
		return
	if replay != null:
		# any tap, click or key skips a replay; the match carries on from where it stopped
		if (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
			replay.skip()
			_end_replay()
			get_viewport().set_input_as_handled()
		return
	if victory != null:
		if (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
			victory.skip()
			_end_victory()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			if pause_rect.has_point(pos) and flow.phase != MatchFlow.Phase.FINAL:
				_pause()
			elif goal_show.active():
				_skip_goal()   # (a tap during a goal never passes, shoots or dives)
			elif flow.phase == MatchFlow.Phase.ATTACK and not aim.active \
					and calls.press(pos, flow.play) != "":
				pass   # (the call strip took it)
			else:
				_press(pos, event.index)
		elif aim.active and event.index == aim.index:
			if event.canceled:
				aim.cancel()   # (the system took the finger: nothing thrown, nothing passed)
			else:
				if aim.stick:
					stick.drag(pos)
					_stick_aim(flow.play)   # (the shot goes where the knob was let go, from where he is now)
				_release()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and aim.active and event.index == aim.index:
		if aim.stick:
			stick.drag(event.position)
		else:
			aim.now = event.position
		get_viewport().set_input_as_handled()

func _press(pos: Vector2, index: int) -> void:
	match flow.phase:
		MatchFlow.Phase.SPRINT:
			if sprint and sprint.started() and not sprint.done:
				sprint.tap()
				Sfx.play("stroke", 1.0 + randf() * 0.2, -4.0)
		MatchFlow.Phase.ATTACK:
			# Only a touch that comes down on the shooting stick (while it's up) can shoot: it's the
			# stick's from here on, wherever the finger goes, and the throw happens on release once
			# we have the ball. Anywhere else it's a tap to pass and nothing more: a pull on the
			# water, a player, the deck never shoots (_release), and never becomes the stick's.
			if aim.active or flow.play.over:
				return
			if stick.hit(pos) and _stick_ready(flow.play):
				aim.begin(index, pos, true)
				stick.take(pos)
			else:
				aim.begin(index, pos)
		MatchFlow.Phase.DEFENSE:
			# you're the keeper: as he winds up or once he's shot, a tap on the goal's left, centre
			# or right is your dive (he tracks the ball by himself until then, and never dives for you).
			# Otherwise a tap on the bar along the bottom is your formation call (FormationBar).
			if flow.can_dive():
				flow.dive_side(_dive_zone(pos.y))
				Sfx.play("splash", 1.3, -6.0)
			else:
				fbar.press(pos, flow)
		MatchFlow.Phase.SHOOTOUT_THEM:
			var n: int = flow.opp.get("lines", []).size()
			if card_shown < n:
				card_shown = n
				card_t = n * LINE_EVERY
				_card_sound()
			else:
				flow.their_ball_done()
		MatchFlow.Phase.THEIR_SHOT:
			# ignore a tap left over from skipping their card
			if flow.duel != null and flow.duel.can_dive() and t - duel_start > DUEL_TAP_GRACE:
				flow.duel.dive(_dive_zone(pos.y))
				Sfx.play("splash", 1.3, -6.0)
		MatchFlow.Phase.BREAK:
			if halftime.tap(pos, flow):
				return   # the adjustment: Q3 waits while it's open
			Sfx.play("click")
			flow.break_done()
		MatchFlow.Phase.FINAL:
			if results != null and not results.ready():
				return
			for b in buttons:
				if (b[0] as Rect2).has_point(pos):
					Sfx.play("click")
					(b[2] as Callable).call()

func _release() -> void:
	var p := flow.play
	if p == null or flow.phase != MatchFlow.Phase.ATTACK:
		aim.cancel()
		return
	if aim.stick:
		if aim.long_enough() and p.can_throw():
			_pull_to_shoot(p)
		elif stick.travel < AimGuide.TAP_SLOP and AimGuide.tap_mate(view, p, aim.start) != null:
			_tap_to_pass(p, aim.start)   # (a tap on a teammate swimming under the stick: his pass)
	elif aim.is_tap():
		_tap_to_pass(p, aim.start)
	aim.cancel()

## The shooting stick is up while you've the ball to shoot with (Play.can_throw) or your pass is on
## its way to one of yours (catch and shoot: the throw goes on release, once he has it). Down,
## it's nothing: a touch there is a touch on the water.
func _stick_ready(p: Play) -> bool:
	return p != null and flow.phase == MatchFlow.Phase.ATTACK and not p.over and not autoplay \
		and (p.can_throw() or (p.ball.state == Ball.State.PASS and p.ball.receiver != null and p.attackers.has(p.ball.receiver)))

## The stick's knob, as a slingshot pull from wherever the shooter is now (AimGuide.stick_at).
## The play's over (a steal, a whistle): the stick lets go and nothing's thrown.
func _stick_aim(p: Play) -> void:
	if not aim.stick:
		return
	if p == null or p.over or flow.phase != MatchFlow.Phase.ATTACK:
		aim.cancel()
	elif p.holder != null and p.holder.side == Swimmer.Side.US:
		aim.stick_at(p.holder, ShotStick.target(p.holder.pos, stick.knob))

## A tap on a teammate passes to him; anywhere else in the pool, to that spot. Off the water, it
## does nothing.
func _tap_to_pass(p: Play, pos: Vector2) -> void:
	var mate := AimGuide.tap_mate(view, p, pos)
	var spot = AimGuide.tap_spot(view, pos)
	if mate != null and p.pass_to(mate):
		spot = p.ball.to
	elif spot == null or not p.pass_at(spot):
		return
	aim.show_mark(spot, t)

## A pull that lands in the goal shoots; a pull aimed anywhere else throws nothing.
func _pull_to_shoot(p: Play) -> void:
	p.shoot_at(aim.target(p.holder), aim.power(p.holder))

func _pause() -> void:
	paused = true
	aim.cancel()
	calls.open = false
	var quit: Array = ["QUIT MATCH", func():
		Sfx.crowd(0.0)
		Game.goto("title")]
	if career:
		quit = ["FORFEIT", _forfeit, "danger"]
	Game.dialog("PAUSED", "%s %d - %d %s" % [Colleges.short_name(flow.us), flow.state.score[0], flow.state.score[1], Colleges.short_name(flow.them)], [
		["RESUME", func(): paused = false, "primary"],
		quit,
	])

## Career: walking off counts as a loss (by at least a goal).
func _forfeit() -> void:
	Game.dialog("FORFEIT?", "Leaving now counts as a loss.", [
		["FORFEIT", _forfeit_now, "danger"],
		["KEEP PLAYING", func(): paused = false, "primary"]])

func _forfeit_now() -> void:
	if flow.phase == MatchFlow.Phase.FINAL:
		_to_career()   # too late to forfeit: the result stands
		return
	var st := flow.state
	st.score[1] = maxi(st.score[1], st.score[0] + 1)
	st.in_shootout = false
	_to_career()

## Career: hand the box score to the career and show the game summary (once).
func _to_career() -> void:
	if handed_over:
		return
	handed_over = true
	Sfx.crowd(0.0)
	var c := Game.career
	c.last_summary = c.finish_my_game(flow.state.box(flow.us, flow.them))
	Game.save_career()
	Game.goto("game_summary")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not paused and flow.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE] and not autoplay:
			_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and not paused:
		if flow.phase == MatchFlow.Phase.FINAL:
			# the game is over: Back means "continue", never "forfeit"
			if career:
				_to_career()
			else:
				Game.goto("title")
		else:
			_pause()

# ------------------------------------------------------------------ drawing
func _draw_all(ci: Control) -> void:
	var size := ci.get_viewport_rect().size
	if intro != null:
		intro.draw(ci, size)
		return
	if replay != null:
		replay.draw(ci, size)
		return
	if victory != null:
		victory.draw(ci, size)
		return
	if not stand_style.is_empty():
		stand_style["close"] = flow.state.quarter >= 4 and absi(int(flow.state.score[0]) - int(flow.state.score[1])) <= 1
	# the world layer, through the 6 on 5 push in (ManUpCam: one transform, the identity at rest);
	# the HUD after it is drawn straight
	ci.draw_set_transform_matrix(view.cine)
	PoolArt.draw_pool(ci, view, t, size, excite, pool, crowd, _net(), stand_style)
	var bodies: Array[Swimmer] = []
	if flow.phase == MatchFlow.Phase.SPRINT and sprint:
		bodies = sprint.bodies()
	elif flow.phase == MatchFlow.Phase.THEIR_SHOT:
		bodies = duel_bodies.duplicate()
	elif flow.play != null:
		bodies = flow.play.bodies()
	bodies.sort_custom(func(a: Swimmer, b: Swimmer): return a.pos.y < b.pos.y)
	var p: Play = flow.play if flow.phase == MatchFlow.Phase.ATTACK else null
	var dp: Play = flow.play if flow.phase == MatchFlow.Phase.DEFENSE else null
	if dp != null:
		DefenseView.draw_under(ci, view, dp, t)
	if p != null and p.can_throw():
		for a in p.attackers:
			if a != p.holder and (p.openness(a) > 1.8 and Geo.range_to_goal(a.pos) < 9.0 \
					or p.center_entry(p.holder.pos, a) == "open"):   # (the centre, his guard on the other side)
				PoolArt.draw_ring(ci, view, a, UI.GOOD)
	if p != null and p.ball.state == Ball.State.PASS and p.ball.receiver != null:
		PoolArt.draw_ring(ci, view, p.ball.receiver, UI.GOLD)
	var lp: Play = p if p != null else dp   # either side's catch and shoot shows
	var glow := lp.catch_glow() if lp != null else 0.0
	if glow > 0.0:
		PoolArt.draw_catch_ring(ci, view, lp.holder, glow)
	for s in bodies:
		HotFire.draw_under(ci, view, s, t)   # (a VERY HOT man's spark ring, under him: HotFire)
		PoolArt.draw_body(ci, view, s, _cap(s), _trim(s), _design(s))
		HotFire.draw_over(ci, view, s, t)
	goal_show.draw_world(ci, view)
	if lp != null:
		PoolArt.draw_release_ring(ci, view, lp.release_by, lp.release_t)
	if flow.phase == MatchFlow.Phase.SPRINT and sprint:
		if not sprint.done:
			PoolArt.draw_ball(ci, view, _sprint_ball())
	elif flow.phase == MatchFlow.Phase.THEIR_SHOT:
		if flow.duel != null:
			_draw_duel(ci, size)
	elif flow.play != null:
		PoolArt.draw_shot_power(ci, view, flow.play.ball)
		PoolArt.draw_shot_fx(ci, view, flow.play.ball)
		HotFire.draw_ball_fire(ci, view, flow.play.ball, t, flow.play.holder)
		PoolArt.draw_ball(ci, view, flow.play.ball)
		PoolArt.draw_net_splash(ci, view, flow.play.ball)
		bar_show.draw_world(ci, view)
		if glow > 0.0:
			PoolArt.draw_catch_glow(ci, view, flow.play.ball, glow)
	if p != null:
		if p.holder != null and p.holder.side == Swimmer.Side.US and not p.over:
			PoolArt.draw_holder_marker(ci, view, p.holder, t)
		aim.draw(ci, view, p, t)
	if dp != null:
		DefenseView.draw_over(ci, view, dp, flow.duel, t)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	goal_fx.draw(ci, size, view)   # (the screen's confetti and lights: never scaled)
	_draw_hud(ci, size)

## A goal's ball in the net, for drawing the net give (PoolArt.draw_pool).
func _net() -> Dictionary:
	var b: Ball = duel_ball if flow.phase == MatchFlow.Phase.THEIR_SHOT else (flow.play.ball if flow.play != null else null)
	if b == null or not b.in_net():
		return {}
	var out := {"x": b.net_line, "y": b.pos.y, "t": b.net_t}
	if b.bar_t >= 0.0:
		out["in_t"] = b.bar_t           # off the frame: the net snaps where it came in, too
		out["in_y"] = (b.bar.at as Vector3).y
	return out

## The ball hit the back of the net: a thump, and a tap of the phone for your goals.
func _net_hit(ours: bool) -> void:
	Sfx.play("splash", 0.7, 1.5)
	Sfx.play("touch", 0.8, -3.0 if ours else -9.0)
	view.shake = maxf(view.shake, 0.6)   # a jolt as the net takes it
	if ours:
		Game.vibrate(25)

func _sprint_ball() -> Ball:
	var b := Ball.new()
	b.pos = sprint.ball
	b.z = 0.0
	return b

## Is this swimmer on your team? In a Play, Side.US is whoever attacks, so while you defend
## it's the other way round.
func _ours(s: Swimmer) -> bool:
	var flipped := flow.phase == MatchFlow.Phase.DEFENSE and flow.play != null and flow.play.defending
	return (s.side == Swimmer.Side.US) != flipped

func _cap(s: Swimmer) -> Color:
	if s.keeper:
		return PoolArt.CAP_KEEPER
	return _us_cap() if _ours(s) else flow.them.cap_against(_us_cap())

func _trim(s: Swimmer) -> Color:
	if _ours(s):
		return Caps.trim_color(Caps.selected(), flow.us.c1)
	return flow.them.trim_against(_us_cap())

## Your caps' colour (white, or your design's); theirs is picked to stand out from it.
func _us_cap() -> Color:
	return Caps.base_color(Caps.selected(), US_CAP)

## Your team wears your cap design (keepers stay in red).
func _design(s: Swimmer) -> String:
	return Caps.selected() if (_ours(s) and not s.keeper) else ""

func _draw_hud(ci: Control, size: Vector2) -> void:
	var ins := _insets()
	var board := Hud.scoreboard(ci, size.x, flow.state, flow.us, flow.them, _us_cap(), flow.them.cap_against(_us_cap()),
		flow.them.trim_against(_us_cap()), goal_show.board_fx())
	pause_rect = Rect2(size.x - ins.y - 24, 3, 20, 19)
	if flow.phase != MatchFlow.Phase.FINAL:
		Hud.pause_button(ci, pause_rect)
	var p: Play = flow.play if flow.phase == MatchFlow.Phase.ATTACK else null
	if p != null:
		calls.layout(stick.area())
		calls.draw(ci, view, p, t)
		if p.kind != Play.Kind.PENALTY:
			Hud.shot_clock(ci, Vector2(board.position.x - 34, 2), p.shot_clock)
			if p.formation_locked or p.ai_drop >= 0:   # (their defence: PRESS, or its drop once called)
				Hud.formation_tag(ci, Vector2(board.position.x - 3, 25), DefenseFormation.NAMES[p.formation])
		if p.man_up > 0.0 and not p.over:
			Hud.man_up(ci, size.x, p.man_up)
		if p.holder != null and p.holder.side == Swimmer.Side.US:
			Hud.holder_tag(ci, Vector2(ins.x + 3, size.y - 15), p.holder.player, flow.state.pf_of(p.holder.player))
		stick.draw(ci, aim.stick)
	var dp: Play = flow.play if flow.phase == MatchFlow.Phase.DEFENSE else null
	if dp != null:
		if dp.kind != Play.Kind.PENALTY:
			Hud.shot_clock(ci, Vector2(board.position.x - 34, 2), dp.shot_clock)
		if dp.man_up > 0.0 and not dp.over:
			Hud.man_up(ci, size.x, dp.man_up, true)
		Hud.holder_tag(ci, Vector2(ins.x + 3, size.y - 15), dp.keeper.player, flow.state.pf_of(dp.keeper.player))
		fbar.layout(size, ins, ins.x + 3 + Hud.tag_parts(dp.keeper.player, flow.state.pf_of(dp.keeper.player)).size.x + 4)
		fbar.draw(ci, flow, t)
	if flow.phase == MatchFlow.Phase.SPRINT and sprint:
		_draw_sprint_hud(ci, size)
	banner.draw(ci, size)
	bar_show.draw(ci, size, view)
	goal_show.draw(ci, size, view)
	broadcast.board_sweep(ci, board, goal_show)
	broadcast.draw(ci, size, _live(), goal_show.active() and goal_show.top > GoalShow.TEXT_TOP, flow.state)
	Hud.dive_note(ci, size, dive_note, t - dive_note_t, goal_show.note_y() if goal_show.active() else -1.0)
	Hud.roll_note(ci, size, roll_note, t - roll_note_t)
	match flow.phase:
		MatchFlow.Phase.SHOOTOUT_THEM:
			_draw_their_card(ci, size)
		MatchFlow.Phase.BREAK:
			_draw_break(ci, size)
		MatchFlow.Phase.FINAL:
			_draw_final(ci, size)

func _draw_sprint_hud(ci: Control, size: Vector2) -> void:
	if not sprint.started():
		var n := int(ceilf(sprint.countdown / 0.6))
		Hud.banner(ci, size, str(clampi(n, 1, 3)), UI.TEXT, 1.0, "GET READY TO TAP")
		if career and flow.state.quarter == 1:
			_venue_pill(ci, size)
	elif not sprint.done:
		var pulse := 1.0 if int(t * 8.0) % 2 == 0 else 0.8
		Hud.banner(ci, size, "TAP TAP TAP!", Color(UI.GOLD, pulse), 1.0, "WIN THE SPRINT FOR THE BALL")
		UI.draw_bar(ci, Rect2(size.x / 2 - 40, size.y - 14, 80, 4), sprint.boost / Sprint.MAX_BOOST, UI.GOOD)

func _draw_their_card(ci: Control, size: Vector2) -> void:
	var lines: Array = []
	var raw: Array = flow.opp.get("lines", [])
	for i in raw.size():
		var col := UI.TEXT
		if i == raw.size() - 1:
			match String(flow.opp.get("tone", "")):
				"good":
					col = UI.GOOD
				"bad":
					col = UI.BAD
		lines.append([raw[i], col])
	Hud.card(ci, size, "THEIR PENALTY", UI.TEXT, lines, card_shown, "TAP TO SKIP")

func _draw_break(ci: Control, size: Vector2) -> void:
	if not flow.state.is_last_quarter():
		var card := Hud.break_card(ci, size, flow.state.quarter, flow.state.score, flow.us, flow.them)
		broadcast.comparison(ci, size, card, flow.state)
		if flow.at_halftime():
			halftime.draw_button(ci, size, card, flow)
			halftime.draw(ci, size, flow)

## Full time: the pool darkens (the scoreboard stays readable) under the results panel.
func _draw_final(ci: Control, size: Vector2) -> void:
	if results == null:
		return
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	Hud.scoreboard(ci, size.x, flow.state, flow.us, flow.them, _us_cap(), flow.them.cap_against(_us_cap()), flow.them.trim_against(_us_cap()))
	var actions: Array = [["CONTINUE >", _to_career]]
	if not career:
		actions = [["REMATCH", _rematch], ["CONTINUE >", func(): Game.goto("title")]]
	buttons = results.draw(ci, size, flow.state, flow.us, flow.them, actions)

func _rematch() -> void:
	Game.match_cfg["seed"] = randi()
	Game.goto("match", Game.match_cfg)

func _insets() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or safe.size.x <= 0:
		return Vector2.ZERO
	var sx := get_viewport_rect().size.x / float(win.x)
	return Vector2(safe.position.x * sx, (win.x - safe.end.x) * sx)

## Career games open with where you're playing: the home team's own pool (its name, the Home
## Waters update), or a neutral site.
func _venue_pill(ci: Control, size: Vector2) -> void:
	var named := String(Game.match_cfg.get("venue", pool.name))
	if named == "":
		Hud.pill(ci, size, "NEUTRAL SITE", UI.ACCENT)
		return
	Hud.pill(ci, size, ("HOME  -  " if Game.match_cfg.get("home", true) else "AWAY  -  ") + named.to_upper(), UI.ACCENT)

# ------------------------------------------------------------------ their shot: you're the keeper
func _start_duel() -> void:
	var d := flow.duel
	duel_end = -1.0
	duel_start = t
	duel_ball = null
	duel_bodies.clear()
	var gk := Swimmer.new(flow.us.keeper(), Swimmer.Side.US, true)
	gk.pos = Vector2(Geo.LENGTH - Geo.KEEPER_X, d.keeper_y)
	gk.facing = 1.0
	duel_bodies.append(gk)
	var shooter := Swimmer.new(flow.opp.shooter, Swimmer.Side.THEM)
	shooter.pos = d.from + Vector2(0.25, 0.05)
	shooter.facing = -1.0
	shooter.arm = 1.0
	duel_bodies.append(shooter)
	if not d.penalty:
		# a defender too late to stop it, and a couple more around the goal
		var field := flow.us.starters().slice(1)
		var att := flow.them.starters().slice(1).filter(func(p): return p != flow.opp.shooter)
		var spots := [[d.from + Vector2(-0.9, 0.5 if d.from.y < Geo.GOAL_Y else -0.5), 0, Swimmer.Side.US],
			[Vector2(2.0, Geo.GOAL_Y + (3.0 if d.from.y < Geo.GOAL_Y else -3.0)), 0, Swimmer.Side.THEM],
			[Vector2(2.6, Geo.GOAL_Y + (2.2 if d.from.y < Geo.GOAL_Y else -2.2)), 1, Swimmer.Side.US]]
		for i in spots.size():
			var sp: Array = spots[i]
			var pl: PoloPlayer = (field[sp[1]] if sp[2] == Swimmer.Side.US else att[i % maxi(1, att.size())])
			var b := Swimmer.new(pl, sp[2])
			b.pos = Geo.clamp_in_pool(sp[0])
			b.facing = 1.0 if sp[2] == Swimmer.Side.US else -1.0
			duel_bodies.append(b)
	view.snap_to(Vector2(4.5 if not d.penalty else 3.5, Geo.GOAL_Y))
	Sfx.play("whistle", 1.25, -8.0)

## A goal past a dive the right way: why it went in, "early" or "late" (KeeperDuel.timing).
func _dive_note(timing: String) -> void:
	dive_note = {"early": "TOO EARLY", "late": "TOO LATE"}.get(timing, "")
	dive_note_t = t

## A tap (mouse or finger, anywhere): which third of your goal it's level with, read across the
## goal as you see it: LEFT (the top of the mouth, and above), CENTRE, RIGHT (the bottom, and below).
func _dive_zone(screen_y: float) -> int:
	return KeeperDive.zone_at_screen(view, screen_y)

func _tick_duel(dt: float) -> void:
	var d := flow.duel
	if d == null:
		return
	if not d.done():
		var game_dt := dt * (d.slowmo if d.state == KeeperDuel.State.FLIGHT else 1.0)
		if autoplay:
			d.bot(game_dt, duel_skill, bot_rng)
		var was := d.state
		d.step(game_dt)
		if was == KeeperDuel.State.WINDUP and d.state == KeeperDuel.State.FLIGHT:
			Sfx.play("splash")
		if d.done():
			_duel_result(d)
	var gk: Swimmer = duel_bodies[0]
	if d.done():
		d.settle(dt)   # his dive plays on: the hold, the recovery
	gk.pos.y = d.keeper_y
	gk.pose = d.anim if d.anim != null and not d.anim.done() else null
	if duel_ball != null and duel_ball.state != Ball.State.DEAD:
		duel_ball.secure_t += dt
		if duel_ball.state == Ball.State.HELD:
			duel_ball.put(Play.held_at(gk))   # saved: in his hands, wherever his dive takes them
		else:
			_drift(duel_ball, dt)
	var shooter: Swimmer = duel_bodies[1]
	shooter.arm = 1.0 if d.state == KeeperDuel.State.WINDUP else maxf(0.0, shooter.arm - dt * 2.0)
	for b in duel_bodies:
		b.anim += dt * 2.0
	if duel_ball != null and duel_ball.step_net(dt * d.slowmo * goal_show.time_scale()):
		_net_hit(false)
	_follow(Vector2(4.5 if not d.penalty else 3.5, Geo.GOAL_Y), dt)
	if duel_end >= 0.0:
		duel_end -= dt
		if duel_end < 0.0:
			_after_show(flow.duel_done)

func _duel_result(d: KeeperDuel) -> void:
	duel_end = END_HOLD
	match d.outcome:
		"goal":
			_dive_note(d.timing())
			Sfx.play("miss")
			duel_ball = Ball.new()
			duel_ball.pos = d.ball_pos()
			duel_ball.z = d.ball_z()
			duel_ball.state = Ball.State.DEAD
			duel_ball.into_net((Vector2(d.goal_x, d.cross_y) - d.from) / d.flight, d.goal_x, 1.0 if d.goal_x > 0.0 else -1.0)
			_start_goal(1, flow.opp.get("shooter"), Vector2(d.goal_x, d.cross_y), flow.their_penalty_wins())
			goal_show.cast(duel_bodies[1], duel_bodies.slice(2), duel_bodies[0])
			_celebrate()
			duel_end = goal_show.total()
		"save":
			_duel_ball(d, Ball.State.HELD)
			duel_bodies[0].arm = 1.0
			banner.event("save")
			Sfx.play("cheer")
			Sfx.play("perfect")
			Game.vibrate(30)
			excite = 0.8
		"parry":
			_duel_ball(d, Ball.State.LOOSE)
			duel_ball.drift = Vector2(signf(d.from.x - d.goal_x) * randf_range(2.5, 4.0), randf_range(-2.5, 2.5))
			banner.event("save")
			Sfx.play("gasp")
			Game.vibrate(20)
		"post":
			banner.show("OFF THE POST!")
			Sfx.play("turn")
		_:
			banner.show("WIDE!")
			Sfx.play("good")

## The duel's ball from where it got to on the line: caught (HELD, eased into his hands) or
## knocked away (LOOSE, on the water as a parry in play goes: Play._go_loose).
func _duel_ball(d: KeeperDuel, st: int) -> void:
	duel_ball = Ball.new()
	duel_ball.pos = d.ball_pos()
	duel_ball.z = d.ball_z()
	duel_ball.state = st
	if st == Ball.State.HELD:
		duel_ball.secure()
	else:
		duel_ball.z = 0.0

## A loose ball on the water, as Play._loose moves one: drifting, slowing.
static func _drift(b: Ball, dt: float) -> void:
	b.pos = Geo.clamp_in_pool(b.pos + b.drift * dt)
	b.drift = b.drift.move_toward(Vector2.ZERO, dt * 3.0)

func _draw_duel(ci: Control, size: Vector2) -> void:
	var d := flow.duel
	var b := duel_ball
	if b == null:
		b = Ball.new()
		b.pos = d.ball_pos()
		b.z = d.ball_z()
		b.state = Ball.State.SHOT
	if d.state == KeeperDuel.State.FLIGHT:
		# the shooter's power, seen: his streak behind the ball (PoolArt.draw_power_trail)
		PoolArt.draw_power_trail(ci, view, Vector3(b.pos.x, b.pos.y, b.z), Vector2(d.goal_x, d.cross_y) - d.from,
			PoolArt.shooter_power(d.shooter_pace * 100.0))
		HotFire.draw_shot_fire(ci, view, Vector3(b.pos.x, b.pos.y, b.z), Vector2(d.goal_x, d.cross_y) - d.from,
			Attributes.hot_stars(d.by), t)
	PoolArt.draw_ball(ci, view, b)
	PoolArt.draw_net_splash(ci, view, b)
