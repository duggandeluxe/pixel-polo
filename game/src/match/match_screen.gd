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
var fbar := FormationBar.new() # your defence's CALL DROP button, bottom right while they attack
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
var break_t0 := 0.0                   # t when the quarter break came up (its scoreboard's drop-in)
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
var level := Difficulty.BASELINE   # difficulty this match is played at (Difficulty): fixed at the start, never moved during it
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
var bot_sprint_t := 0.0        # autoplay: seconds since the sprint's whistle
var goal_fx := GoalFx.new()    # the equipped Goal Celebration, at the goal (GoalFx)
var broadcast := BroadcastFx.new()   # the Broadcast Presentation level's graphics
var stand_style := {}          # the Crowd Atmosphere level (CrowdArt.style; {}: the plain crowd)
var crowd_seed := 0            # the stands' seating for this match (CrowdArt.style's seed)

## LIVE SIM (the pause menu's SIM): the rest of the match plays itself, both teams on the computer's
## brain (MatchFlow.sim_us, OffenseAI; your keeper on KeeperDuel.bot at your keeper's own read),
## watched fast-forwarded like a TV broadcast. Nothing about the match changes but who decides for
## you and how fast it's shown: every frame is cut into fixed SIM_STEP steps of the ordinary match
## (_frame), so the players, the ball, the clocks and every rule run exactly as in play, just more
## of them a second. A shot (its wind-up and flight), the whistle after a possession and above all
## a goal's show ease the speed down so you can see them; then it spins back up.
## SIM_PACE scales every SIM playback speed below (and shortens the break card to match): how
## fast the broadcast is shown, never what happens in it.
const SIM_PACE := 1.2
const SIM_SPEED := 16.0 * SIM_PACE     # x normal: ordinary play...
const SIM_SPEED_MIN := 4.0 * SIM_PACE  # ...never backed off below this on a device that can't keep up
const SIM_SHOT := 5.0 * SIM_PACE       # ...a shot winding up or in the air
const SIM_HOLD := 5.0 * SIM_PACE       # ...the whistle's moment after a possession (SAVE!, STEAL!, the sprint's result)
const SIM_GOAL := 1.8 * SIM_PACE       # ...a goal's show (GoalShow.total, ~2.6 s): about 1.2 s on the screen
const SIM_BREAK := 1.2 / SIM_PACE      # real seconds a quarter break's card stays up before play carries on
const SIM_STEP := 1.0 / 60.0   # the fixed step SIM frames are cut into (a normal 60 Hz frame)
const SIM_MAX_STEPS := 20      # steps one frame may run at most (>= SIM_SPEED at 60 fps): the rest is dropped, never owed
const SIM_BUDGET_MS := 9.0     # ...and the time it may spend on them before the speed backs off
const SIM_EASE_DOWN := 60.0    # 1/s: into a slowdown (near at once: the shot mustn't race past)
const SIM_EASE_UP := 12.0      # 1/s: back up to speed (a tape spinning up, ~0.3 s)
const SIM_CAM := 3.0 * SIM_PACE  # the camera follows at most this much faster than in play: steady
const SIM_IN := 0.35           # s: the switch-on, a TV coming on
var sim := false
var sim_rate := 1.0            # x normal right now (eased towards _sim_target)
var sim_cap := SIM_SPEED       # the most this device manages (backs off, recovers)
var sim_acc := 0.0             # match seconds owed to the fixed steps
var sim_t := 0.0               # real seconds in SIM (the indicator's blink)
var sim_in := 0.0              # the switch-on, 1 -> 0
var sim_break_t := 0.0         # real seconds the break card's been up
var sim_return := false        # RETURN TO GAME: control comes back at the next safe moment (_sim_safe)
var sim_keeper := 0.5          # your keeper's dive timing on the bot (KeeperDuel.bot), from his own Lunge Speed
var sim_sprint := 0.0          # your sprinter as the computer swims theirs (MatchFlow.sprint_speed_of)
var sim_rect := Rect2()        # the PAUSE control
var jump_rect := Rect2()       # JUMP IN, bottom right: RETURN TO GAME in one tap
var jump_down := 0.0           # real s JUMP IN shows pressed before it hands over (a click you can see)
var jump_hand := false         # the pointing-hand cursor is up (over JUMP IN)
const JUMP_PRESS := 0.09
var sim_steps := 0             # (tests and the speed report) fixed steps run...
var sim_real := 0.0            # ...over this many real seconds
var sim_runs := 0              # (tests) times SIM has been switched on
var sim_at_start := false      # START IN SIM (the game preview): SIM switches on at kickoff, once the intro is over
# SIM TO END (the career pause menu): the rest of the match worked out at once from the teams'
# ratings (SimFinish: no frames played, no loading screen), from exactly where it was, then full
# time as ever
var sim_ends := 0              # times SIM TO END has run (once a match)
var sim_end_ms := -1.0         # (tests, the speed report) real ms it took, confirm to full time
var neutral_site := false      # a neutral pool: no home edge in SIM TO END's numbers

func setup(params: Dictionary) -> void:
	var cfg: Dictionary = params if not params.is_empty() else Game.match_cfg
	autoplay = cfg.get("autoplay", false)
	sim_at_start = bool(cfg.get("start_sim", false))
	career =cfg.get("career", false) and Game.career != null
	level = float(cfg.get("level", Difficulty.level_for(career)))
	flow = MatchFlow.new(cfg.us, cfg.them, int(cfg.get("seed", randi())), float(cfg.get("minutes", MatchState.QUARTER_MIN)), level)
	flow.home = cfg.get("home", true)
	neutral_site = bool(cfg.get("neutral", false))
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
	crowd_seed = randi()   # (who sits where: fixed for the whole match)
	stand_style = CrowdArt.style(CrowdArt.level_for(Store.looks.worn("crowd")), home_side, flow.them if home_side == flow.us else flow.us, bool(cfg.get("neutral", false)), crowd, HotFire.calm(),
		int(cfg.get("importance", 0)), crowd_seed)
	broadcast = BroadcastFx.new(Store.looks.worn("broadcast"), HotFire.calm())
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
	if sim_at_start and intro == null:
		sim_at_start = false   # START IN SIM: the same match from 0:00, the broadcast from the first whistle
		_start_sim()
	if sim:
		_sim_process(dt)
		return
	_frame(dt)

## One frame of the match, `dt` seconds of its time: the real frame in play, one SIM_STEP in SIM.
func _frame(dt: float) -> void:
	if intro != null:
		_tick_intro(dt)
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
	_tick_man_up_cam(dt * _cam_rate())
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

# ------------------------------------------------------------------ after a goal's show
## The goal's show is over: `then` (the goal's counted there, as it always was).
func _after_show(then: Callable) -> void:
	_end_goal_show()
	then.call()

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
			if sim:
				sim_sprint = MatchFlow.sprint_speed_of(flow.us, bot_rng)
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
				break_t0 = t
				Sfx.play("bell")
		MatchFlow.Phase.FINAL:
			if sim:
				_end_sim()   # full time: the results and everything after at their own pace
			Sfx.crowd(0.0)
			results = ResultsPanel.new().setup(flow.state,
				Game.career.records_after(flow.state.winner() == 0) if career and Game.career != null else {})
			if not autoplay:
				# (a completed game: the only time DYNAMIC moves)
				Difficulty.after_game(career, flow.state.score[0], flow.state.score[1], flow.us, flow.them)
			var won := flow.state.winner() == 0
			Sfx.music("victory" if won else "")
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
	if sim and sprint.started() and not sprint.done:
		# SIM: your sprinter swims as theirs does (his speed, no taps): the boost that gives it
		var jet := Sprint.JET_BONUS if Traits.has(sprint.ours.player, "jet") else 0.0
		sprint.boost = clampf(sim_sprint - Sprint.BASE_SPEED - jet, 0.0, Sprint.MAX_BOOST) + dt * Sprint.BOOST_DECAY
	sprint.step(dt)
	view.follow(sprint.focus(), dt * _cam_rate())
	if sprint.whistled and not was:
		Sfx.play("whistle")
	# (the bot's tapping keeps its own time from the sprint's start: a presentation before it, or a
	# frame's real length, must not be able to change who wins it)
	bot_sprint_t = bot_sprint_t + dt if sprint.started() else 0.0
	if autoplay and not sim and sprint.started() and int(bot_sprint_t * 12.0) % 2 == 0:
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
	if sim:
		pass   # (the computer's brain plays it: MatchFlow.sim_us)
	elif autoplay:
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
	view.follow(focus, dt * _cam_rate())

## The camera's share of a frame's match time: all of it in play; in SIM never more than SIM_CAM
## times a real frame, so the fast-forward is watched from a steady camera.
func _cam_rate() -> float:
	return 1.0 if not sim else minf(1.0, SIM_CAM / maxf(sim_rate, 1.0))

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
				if not sim:   # (SIM: the small sounds would chatter at speed)
					Sfx.play("stroke", 1.3, -6.0)
			"catch":
				if not sim:
					Sfx.play("touch", 1.1, -8.0)
			"drive":
				if not defending:
					banner.show("DRIVE %s!" % CallStrip.LABELS.get(e.side, ""), EventBanner.YELLOW)
			"windup":
				if defending:   # (SIM: your own shooter winds up on the same brain)
					banner.show("HE'S SHOOTING!", EventBanner.RED)
			"ball_down":
				if not sim:
					Sfx.play("splash", 1.6, -12.0)
			"shot":
				if float(e.get("catch_shoot", 0.0)) > 0.0:
					Sfx.play("splash", 0.9, 2.5)   # a catch and shoot: a touch heavier
					_vibrate(22)
				else:
					Sfx.play("splash")
					_vibrate(15)
			"save":
				Sfx.play("gasp")
			"rebound":
				Sfx.play("turn")
				_rebound(String(e.text))
			"block":
				Sfx.play("turn")
				_vibrate(20)
				banner.event("block")
			"foul":
				Sfx.play("whistle", 1.15, -5.0)
				banner.event("foul")
			"tip":
				Sfx.play("turn")
				_vibrate(12)
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
			_vibrate(30)
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
			_vibrate(25)
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
	goal_fx.start(GoalFx.equipped(), goal_show, team.c1, team.c2, HotFire.calm())
	var sc: Array = flow.state.score.duplicate()
	sc[side] = int(sc[side]) + 1
	broadcast.goal(who, team, goal_show.goals_today, (flow.state.shot_by[side] as Array).count(who), "%d-%d" % [int(sc[0]), int(sc[1])])
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

## The phone's buzz for a moment in play (never in SIM: it's a broadcast you're watching).
func _vibrate(ms: int) -> void:
	if not sim:
		Game.vibrate(ms)

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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8 \
			and bool(Game.settings.get("dev_mode", false)):
		cycle_board()   # (Developer Mode: the next scoreboard tier; the match never notices)
		get_viewport().set_input_as_handled()
		return
	if sim:
		# SIM: nothing reaches the match; the PAUSE control (or Esc) stops the broadcast
		if event is InputEventScreenTouch and event.pressed and jump_rect.has_point(event.position):
			if jump_down <= 0.0:
				Sfx.play("click")
				jump_down = JUMP_PRESS   # (pressed in for a moment, then _process hands over)
				canvas.queue_redraw()
		elif event is InputEventScreenTouch and event.pressed and (sim_rect.has_point(event.position) or pause_rect.has_point(event.position)):
			_sim_pause()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_sim_pause()
		get_viewport().set_input_as_handled()
		return
	if intro != null:
		# any tap, click or key skips the entrance (the match then starts, once)
		if (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
			intro.skip()
			_end_intro()
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
			# Otherwise a tap on CALL DROP, bottom right, calls your drop (FormationBar).
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
	return p != null and flow.phase == MatchFlow.Phase.ATTACK and not p.over and not autoplay and not sim \
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
	var opts: Array = [
		["RESUME", func(): paused = false, "primary"],
		["SIM", _start_sim],
		_quit_button(),
	]
	if bool(Game.settings.get("dev_mode", false)):   # Developer Mode: the scoreboard's tiers, on the spot
		opts.insert(1, ["BOARD %d" % Scoreboard.tier(), func():
			cycle_board()
			_pause.call_deferred()])
		if not stand_style.is_empty():   # ...and the Crowd Atmosphere levels
			opts.insert(2, ["CROWD %d" % int(stand_style.lv), func():
				cycle_crowd()
				_pause.call_deferred()])
	Game.dialog("PAUSED", _score_line(), opts)

## Developer Mode: the next scoreboard tier for the rest of the session (Scoreboard.override,
## never saved). Only the drawing changes: the match, its clocks and its score carry on as they were.
func cycle_board() -> void:
	if not bool(Game.settings.get("dev_mode", false)):
		return
	Scoreboard.override = Scoreboard.tier() % Scoreboard.TOP + 1
	Game.toast("SCOREBOARD: TIER %d %s" % [Scoreboard.override, Scoreboard.NAMES[Scoreboard.override - 1]], UI.GOLD)

## Developer Mode: the next Crowd Atmosphere level in this match (CrowdArt.override, never saved,
## nothing owned). The same seats for the same level: only the stands' picture changes. The
## entrance shares the dict, so it follows.
func cycle_crowd() -> void:
	if not bool(Game.settings.get("dev_mode", false)) or stand_style.is_empty():
		return
	CrowdArt.override = int(stand_style.lv) % CrowdArt.TOP + 1
	var st := CrowdArt.style(CrowdArt.override, stand_style.home, stand_style.away, bool(stand_style.neutral), crowd, bool(stand_style.calm),
		1 if bool(stand_style.big) else 0, crowd_seed)
	stand_style.merge(st, true)
	Game.toast("CROWD: LEVEL %d %s" % [CrowdArt.override, CrowdArt.NAMES[CrowdArt.override - 1]], UI.GOLD)

func _score_line() -> String:
	return "%s %d - %d %s" % [Colleges.short_name(flow.us), flow.state.score[0], flow.state.score[1], Colleges.short_name(flow.them)]

## The pause menu's last button: SIM TO END in a career, QUIT MATCH otherwise.
func _quit_button() -> Array:
	if career:
		return ["SIM TO END", _sim_to_end, "danger"]
	return ["QUIT MATCH", func():
		Sfx.crowd(0.0)
		Game.goto("title")]

## Career: SIM TO END asks first (the match stays paused, untouched, while it's up).
func _sim_to_end() -> void:
	paused = true
	Game.dialog("SIM TO END?", "Are you sure you want to simulate the rest of this game? You will not be able to return to gameplay once the simulation begins.", [
		["CANCEL", _sim_to_end_cancel, "primary"],
		["SIM TO END", _sim_to_end_now, "danger"]], "danger")

## CANCEL: back to the pause menu it came from, nothing changed.
func _sim_to_end_cancel() -> void:
	if sim_ends > 0:
		return
	paused = false   # (only so the menu can open again: no frame runs in between)
	if sim:
		_sim_pause()
	else:
		_pause()

## SIM TO END confirmed: the rest of the match worked out at once (SimFinish: the scoring engine's
## numbers for the time left, from exactly where the match is: score, clocks, possession, fouls,
## exclusions, the box score, nothing reset), then the final whistle in the same call: the
## full-time panel and the career's postgame, as a played game. No frames of play, no loading
## screen, no win celebration in between. Once.
func _sim_to_end_now() -> void:
	if sim_ends > 0 or handed_over:
		return
	if flow.phase == MatchFlow.Phase.FINAL:
		paused = false   # (already over: the result stands)
		return
	var t0 := Time.get_ticks_usec()
	sim_ends += 1
	if sim:
		_end_sim()
	_settle_for_sim_end()
	aim.cancel()
	calls.open = false
	halftime.open = false
	SimFinish.run(flow, neutral_site, flow.rng.randi())
	paused = false
	_frame(0.0)   # full time: _enter_phase puts the results up
	sim_end_ms = (Time.get_ticks_usec() - t0) / 1000.0
	canvas.queue_redraw()

## Before SIM TO END: whatever has already happened is counted, the way the next frames would
## have (a goal under its show, a possession's end held for its banner, their penalty's
## result): the box score and score SimFinish carries on from are the whole of the match so far.
## A possession still live is cut where it is (what it did stands; the rest is SimFinish's).
func _settle_for_sim_end() -> void:
	_end_goal_show()
	if flow.phase == MatchFlow.Phase.THEIR_SHOT and flow.duel != null and duel_end >= 0.0:
		duel_end = -1.0
		flow.duel_done()
	elif flow.play != null and (end_timer >= 0.0 or flow.play.over):
		end_timer = -1.0
		if flow.phase == MatchFlow.Phase.ATTACK:
			flow.attack_done()
		elif flow.phase == MatchFlow.Phase.DEFENSE:
			flow.defense_done()

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

# ------------------------------------------------------------------ LIVE SIM
## A real frame of SIM: the match on at sim_rate, in fixed SIM_STEP steps (the speed eased
## towards _sim_target; never more than SIM_MAX_STEPS or SIM_BUDGET_MS a frame, and a device that
## can't keep up backs the speed off by itself), then what SIM does by itself between steps.
func _sim_process(dt: float) -> void:
	dt = minf(dt, 0.1)   # (a hitch is never paid back as a burst)
	sim_t += dt
	sim_real += dt
	sim_in = maxf(0.0, sim_in - dt / SIM_IN)
	var target := _sim_target()
	var k := SIM_EASE_DOWN if target < sim_rate else SIM_EASE_UP
	sim_rate = lerpf(sim_rate, target, 1.0 - exp(-k * dt))
	if absf(sim_rate - target) < 0.05:
		sim_rate = target
	sim_acc += dt * sim_rate
	var t0 := Time.get_ticks_usec()
	var n := 0
	while sim and not paused and sim_acc >= SIM_STEP and n < SIM_MAX_STEPS:
		_frame(SIM_STEP)
		sim_acc -= SIM_STEP
		n += 1
		sim_steps += 1
		if (Time.get_ticks_usec() - t0) > SIM_BUDGET_MS * 1500.0:
			break   # (well over budget: the frame goes out now)
	sim_acc = minf(sim_acc, SIM_STEP)   # (what didn't fit is dropped, not owed)
	if sim and flow.phase == MatchFlow.Phase.FINAL:
		_frame(0.0)   # full time in the last step: SIM ends now, not a frame later (_enter_phase)
	if n >= 4:
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		if ms > SIM_BUDGET_MS:
			sim_cap = maxf(SIM_SPEED_MIN, sim_cap - 0.5)
		elif ms < SIM_BUDGET_MS * 0.4:
			sim_cap = minf(SIM_SPEED, sim_cap + dt)
	if not sim:
		return
	# JUMP IN pressed: a moment showing pressed in, then control comes back (RETURN TO GAME)
	if jump_down > 0.0:
		jump_down -= dt
		if jump_down <= 0.0:
			jump_down = 0.0
			_sim_return_now()
			if not sim:
				return
	# a quarter break: its card for a moment, then on (the halftime adjustment stays yours to make
	# only when you're playing)
	if flow.phase == MatchFlow.Phase.BREAK:
		sim_break_t += dt
		halftime.open = false
		if sim_break_t >= SIM_BREAK and not sim_return:
			sim_break_t = 0.0
			flow.break_done()
	else:
		sim_break_t = 0.0
	if sim_return and _sim_safe():
		_end_sim()
	canvas.queue_redraw()

## How fast SIM wants to run now (x normal): a goal's show slowly enough to see it, a shot and the
## whistle after a possession a little slower, everything else flat out. RETURN TO GAME on its way:
## normal speed until it hands over.
func _sim_target() -> float:
	if sim_return:
		return 1.0
	if goal_show.active():
		return SIM_GOAL
	var top := sim_cap
	match flow.phase:
		MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE:
			var p := flow.play
			if p != null:
				if p.ball.state == Ball.State.SHOT or flow.duel != null or bool(flow.opp_plan.get("shot", false)):
					return minf(SIM_SHOT, top)
				if p.over or end_timer >= 0.0:
					return minf(SIM_HOLD, top)
		MatchFlow.Phase.THEIR_SHOT:
			return minf(SIM_SHOT, top)
		MatchFlow.Phase.SHOOTOUT_THEM:
			return minf(SIM_HOLD, top)
		MatchFlow.Phase.SPRINT:
			if sprint_end >= 0.0:
				return minf(SIM_HOLD, top)
		MatchFlow.Phase.BREAK:
			return 1.0
	return top

## The pause menu's SIM: from exactly where the match is, the computer takes your side and the
## broadcast starts. The score, the clocks, the possession, everybody's place: all as they were.
func _start_sim() -> void:
	paused = false
	if flow.phase == MatchFlow.Phase.FINAL or sim:
		return
	sim = true
	sim_runs += 1
	sim_return = false
	sim_rate = 1.0   # (from normal speed: the tape spins up)
	sim_acc = 0.0
	sim_in = 1.0
	sim_t = 0.0
	sim_break_t = 0.0
	aim.cancel()
	calls.open = false
	halftime.open = false
	flow.set_sim(true)
	sim_keeper = _sim_keeper_skill()
	flow.auto_keeper = sim_keeper
	sim_sprint = MatchFlow.sprint_speed_of(flow.us, bot_rng)
	Sfx.play("card", 1.3, -6.0)

## The pointing hand over JUMP IN (the match canvas takes no mouse itself, so it's set by hand).
func _jump_cursor(on: bool) -> void:
	if on != jump_hand:
		jump_hand = on
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if on else Input.CURSOR_ARROW)

func _exit_tree() -> void:
	_jump_cursor(false)

## SIM off (RETURN TO GAME once it's safe, or full time): your side's yours again, at normal
## speed, the HUD and controls back, from wherever the match got to.
func _end_sim() -> void:
	_jump_cursor(false)
	jump_down = 0.0
	if not sim:
		return
	sim = false
	sim_return = false
	sim_rate = 1.0
	sim_acc = 0.0
	flow.set_sim(false)
	flow.auto_keeper = duel_skill if autoplay else -1.0
	aim.cancel()

## Your keeper's dive timing on the bot: his own Lunge Speed (his reactions, Hot / Cold and all),
## about the tests' even 0.5 for an average keeper. His saves are still his attributes' (KeeperDuel).
func _sim_keeper_skill() -> float:
	return clampf(0.35 + 0.3 * Attributes.keeper_skill(flow.us.keeper(), "lun"), 0.3, 0.7)

## Can control come back now? Only with the ball live and nothing in the air or being settled:
## never during a goal's show, a whistle's hold, a shot or its wind-up, a penalty's duel, or a
## sprint already under way. A break, the sprint's countdown and their shootout card are fine.
func _sim_safe() -> bool:
	if goal_show.active() or end_timer >= 0.0:
		return false
	match flow.phase:
		MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE:
			var p := flow.play
			return p != null and not p.over and flow.duel == null and p.ball.state != Ball.State.SHOT \
				and not bool(flow.opp_plan.get("shot", false)) and flow.keeper_anim == null
		MatchFlow.Phase.SPRINT:
			return sprint != null and not sprint.started()
		MatchFlow.Phase.BREAK, MatchFlow.Phase.SHOOTOUT_THEM, MatchFlow.Phase.FINAL:
			return true
	return false

## SIM's own pause: carry on watching, take your team back, or the usual way out.
func _sim_pause() -> void:
	if paused or not sim:
		return
	paused = true
	Game.dialog("SIM PAUSED", _score_line(), [
		["CONTINUE SIM", func(): paused = false, "primary"],
		["RETURN TO GAME", _sim_return_now],
		_quit_button(),
	])

## RETURN TO GAME: control back now if it's safe, otherwise at the next safe moment (normal speed
## until then: _sim_target).
func _sim_return_now() -> void:
	paused = false
	if not sim:
		return
	sim_return = true
	if _sim_safe():
		_end_sim()

## The speed SIM has managed so far: match seconds a real second (tests, the report).
func sim_speed() -> float:
	return sim_steps * SIM_STEP / sim_real if sim_real > 0.0 else 0.0

## The broadcast look, over everything and kept faint: a dark edge, light scanlines, the tag in
## the corner (SIM, ▶▶ at speed / ▶ slowed down, the speed) with the PAUSE control beside it, and
## the TV coming on at the start.
func _draw_sim(ci: Control, size: Vector2) -> void:
	# the screen edge, a few pixels darker
	for i in 6:
		ci.draw_rect(Rect2(i, i, size.x - 2 * i, size.y - 2 * i), Color(0.0, 0.02, 0.08, 0.16 * (1.0 - i / 6.0)), false, 1.0)
	# scanlines: one dark row in three
	var y := 1.0
	var line := Color(0.0, 0.0, 0.05, 0.045)
	while y < size.y:
		ci.draw_rect(Rect2(0, y, size.x, 1), line)
		y += 3.0
	var ins := _insets()
	# the tag, bottom left (where your man's tag is in play): SIM and the fast-forward arrows (they
	# chase at speed; one, still, slowed down)
	var fast := sim_rate >= SIM_HOLD - 0.01 and not sim_return
	var word := "RETURNING" if sim_return else "SIM"
	var tw := UI.text_width(word, 8, "caps")
	var tag := Rect2(ins.x + 4, size.y - 17, tw + (UI.text_width("%dX" % roundi(sim_rate), 8, "caps") + 28 if fast else 21), 13)
	ci.draw_rect(tag, Color(Hud.PANEL_BG, 0.9))
	ci.draw_rect(tag, Color(UI.BORDER, 0.85), false, 1.0)
	var dot := Color(UI.BAD, 1.0 if int(sim_t * 2.0) % 2 == 0 else 0.45)   # (the broadcast light)
	ci.draw_rect(Rect2(tag.position + Vector2(4, 5), Vector2(3, 3)), dot)
	UI.text(ci, tag.position + Vector2(10, 10), word, 8, UI.TEXT, "caps")
	var ax := tag.position.x + 12 + tw
	var ay := tag.position.y + 3
	var arrows := 2 if fast else 1
	for i in arrows:
		var lit := not fast or int(sim_t * 8.0) % 2 == i
		var c := Color(UI.GOLD, 1.0 if lit else 0.5)
		var x0 := ax + i * 5
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x0, ay), Vector2(x0 + 5, ay + 3.5), Vector2(x0, ay + 7)]), c)
	if fast:
		UI.text(ci, Vector2(ax + 12, tag.position.y + 10), "%dX" % roundi(sim_rate), 8, UI.DIM, "caps")
	# PAUSE, where the pause button always is (the same chunky little panel)
	if flow.phase != MatchFlow.Phase.FINAL:
		var pw := UI.text_width("PAUSE", 8, "caps") + 10
		sim_rect = Rect2(size.x - ins.y - 4 - pw, 3, pw, 19)
		ci.draw_rect(sim_rect, UI.PANEL)
		ci.draw_rect(sim_rect, UI.BORDER, false, 1.0)
		UI.text(ci, sim_rect.position + Vector2(5, 13), "PAUSE", 8, UI.TEXT, "caps")
	# JUMP IN, bottom right (opposite the tag): your team back from this very moment. Gone once
	# it's been pressed (the tag reads RETURNING until control is safely handed over).
	jump_rect = Rect2()
	if flow.phase != MatchFlow.Phase.FINAL and not sim_return:
		var tw2 := UI.text_width("JUMP IN", 8, "caps")
		var jw := tw2 + 26   # (room for the chevron)
		jump_rect = Rect2(size.x - ins.y - 7 - jw, size.y - 28, jw, 21)
		var hover := jump_rect.has_point(ci.get_local_mouse_position())
		_jump_cursor(hover)
		# a soft pulse around it (it's the one thing on the broadcast you can press)
		var pulse := 0.5 + 0.5 * sin(sim_t * 4.0)
		if jump_down <= 0.0:
			for i in 2:
				var g := jump_rect.grow(2 + i)
				ci.draw_rect(g, Color(UI.GOLD, (0.45 - 0.2 * i) * (0.35 + 0.65 * pulse)), false, 1.0)
		var mode := "down" if jump_down > 0.0 else ("hover" if hover else "normal")
		var face := Deck.button_face(ci, jump_rect, UI.GOLD, UI.INK, mode)
		var tx := face.position.x + 7
		UI.text(ci, Vector2(tx, face.position.y + 14), "JUMP IN", 8, UI.INK, "caps")
		# the chevron, nudging right on hover (PLAY GAME's >)
		var cx := tx + tw2 + 5 + (1.0 if hover else 0.0)
		var cy := face.position.y + 6
		ci.draw_colored_polygon(PackedVector2Array([Vector2(cx, cy), Vector2(cx + 5, cy + 4.5), Vector2(cx, cy + 9)]), UI.INK)
	else:
		_jump_cursor(false)
	# the TV coming on: a bright line that opens into the picture
	if sim_in > 0.0:
		var u := 1.0 - sim_in
		var open := size.y * u * u
		var top := (size.y - open) * 0.5
		var cover := Color(0.0, 0.02, 0.06, 0.85 * sim_in)
		ci.draw_rect(Rect2(0, 0, size.x, top), cover)
		ci.draw_rect(Rect2(0, top + open, size.x, size.y - top - open), cover)
		ci.draw_rect(Rect2(0, top - 1, size.x, 1), Color(1, 1, 1, 0.7 * sim_in))
		ci.draw_rect(Rect2(0, top + open, size.x, 1), Color(1, 1, 1, 0.7 * sim_in))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not paused and flow.phase in [MatchFlow.Phase.ATTACK, MatchFlow.Phase.DEFENSE] and not autoplay:
			if sim:
				_sim_pause()
			else:
				_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and not paused:
		if flow.phase == MatchFlow.Phase.FINAL:
			# the game is over: Back means "continue", never "forfeit"
			if career:
				_to_career()
			else:
				Game.goto("title")
		elif sim:
			_sim_pause()
		else:
			_pause()

# ------------------------------------------------------------------ drawing
func _draw_all(ci: Control) -> void:
	var size := ci.get_viewport_rect().size
	if intro != null:
		intro.draw(ci, size)
		return
	if not stand_style.is_empty():
		stand_style["close"] = flow.state.quarter >= 4 and absi(int(flow.state.score[0]) - int(flow.state.score[1])) <= 1
	# the world layer, through the 6 on 5 push in (ManUpCam: one transform, the identity at rest);
	# the HUD after it is drawn straight
	ci.draw_set_transform_matrix(view.cine)
	PoolArt.draw_pool(ci, view, t, size, excite, pool, crowd, _net(), stand_style)
	goal_fx.draw_world(ci, view)   # (the celebration's poppers, rockets and ripples: under the swimmers)
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
	if p != null and p.can_throw() and not sim:
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
		if p.holder != null and p.holder.side == Swimmer.Side.US and not p.over and not sim:
			PoolArt.draw_holder_marker(ci, view, p.holder, t)
		aim.draw(ci, view, p, t)
	if dp != null:
		DefenseView.draw_over(ci, view, dp, flow.duel, t)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	goal_fx.draw(ci, size, view)   # (the celebration over the goal: over everything, the HUD aside)
	_draw_hud(ci, size)
	if sim:
		_draw_sim(ci, size)

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
		_vibrate(25)

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

## The bottom-left tag's man: Play.holder's player, whichever side he's on (their man on the
## ball while you defend, a keeper only once he has it). While nobody has it (a pass, a shot, a
## loose ball) the last man to hold it this possession stays up; a new possession starts clean.
## `_tag_room`: the widest tag this possession could show (its attackers, its keeper), so CALL
## DROP keeps one place while the ball moves.
var _tag_play: Play = null
var _tag_player: PoloPlayer = null
var _tag_room := 0.0

func _tag_holder(p: Play) -> PoloPlayer:
	if p != _tag_play:
		_tag_play = p
		_tag_player = null
		_tag_room = 0.0
		for s in p.attackers:
			_tag_room = maxf(_tag_room, Hud.tag_parts(s.player).size.x)
		if p.keeper != null:
			_tag_room = maxf(_tag_room, Hud.tag_parts(p.keeper.player).size.x)
	if p.holder != null:
		_tag_player = p.holder.player
	return _tag_player

func _draw_hud(ci: Control, size: Vector2) -> void:
	var ins := _insets()
	var tier := Scoreboard.tier()   # (read every frame: Developer Mode can switch it mid-match)
	var board := Hud.scoreboard(ci, size.x, flow.state, flow.us, flow.them, _us_cap(), flow.them.cap_against(_us_cap()),
		flow.them.trim_against(_us_cap()), goal_show.board_fx(), tier)
	var under := Scoreboard.below(board)
	pause_rect = Rect2(size.x - ins.y - 24, 3, 20, 19)
	sim_rect = Rect2()
	jump_rect = Rect2()
	if flow.phase != MatchFlow.Phase.FINAL and not sim:
		Hud.pause_button(ci, pause_rect)
	var p: Play = flow.play if flow.phase == MatchFlow.Phase.ATTACK else null
	if p != null:
		calls.layout(stick.area())
		if not sim:
			calls.draw(ci, view, p, t)
		if p.kind != Play.Kind.PENALTY:
			var sc := Scoreboard.shot_clock(ci, tier, board, minf(p.shot_clock, flow.state.clock))   # (never more than the game clock has left)
			if p.formation_locked or p.ai_drop >= 0:   # (their defence: PRESS, or its drop once called)
				Hud.formation_tag(ci, Vector2(sc.end.x + 1.0, maxf(under, sc.end.y + 2.0)), DefenseFormation.NAMES[p.formation])
		if p.man_up > 0.0 and not p.over:
			Hud.man_up(ci, size.x, p.man_up, false, under)
		var hp := _tag_holder(p)
		if hp != null and not sim:
			Hud.holder_tag(ci, Vector2(ins.x + 3, size.y - 15), hp)
		if not sim:
			stick.draw(ci, aim.stick)
	var dp: Play = flow.play if flow.phase == MatchFlow.Phase.DEFENSE else null
	if dp != null:
		if dp.kind != Play.Kind.PENALTY:
			Scoreboard.shot_clock(ci, tier, board, minf(dp.shot_clock, flow.state.clock))
		if dp.man_up > 0.0 and not dp.over:
			Hud.man_up(ci, size.x, dp.man_up, true, under)
		if not sim:   # (the holder's tag and CALL DROP are controls: SIM plays them)
			var dh := _tag_holder(dp)
			if dh != null:
				Hud.holder_tag(ci, Vector2(ins.x + 3, size.y - 15), dh)
			fbar.layout(size, ins, ins.x + 3 + _tag_room + 4)
			fbar.draw(ci, flow, t)
	if flow.phase == MatchFlow.Phase.SPRINT and sprint:
		_draw_sprint_hud(ci, size, under)
	banner.draw(ci, size)
	bar_show.draw(ci, size, view)
	goal_show.draw(ci, size)
	broadcast.board_sweep(ci, board, goal_show)
	broadcast.draw(ci, size, _live(), flow.state)
	Hud.dive_note(ci, size, dive_note, t - dive_note_t, goal_show.note_y() if goal_show.active() else -1.0)
	Hud.roll_note(ci, size, roll_note, t - roll_note_t)
	match flow.phase:
		MatchFlow.Phase.SHOOTOUT_THEM:
			_draw_their_card(ci, size)
		MatchFlow.Phase.BREAK:
			_draw_break(ci, size)
		MatchFlow.Phase.FINAL:
			_draw_final(ci, size)

func _draw_sprint_hud(ci: Control, size: Vector2, under: float = 25.0) -> void:
	if not sprint.started():
		var n := int(ceilf(sprint.countdown / 0.6))
		Hud.banner(ci, size, str(clampi(n, 1, 3)), UI.TEXT, 1.0, "GET READY TO TAP")
		if career and flow.state.quarter == 1:
			_venue_pill(ci, size, maxf(30.0, under + 2.0))
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
		var card := Hud.break_card(ci, size, flow.state.quarter, flow.state.score, flow.us, flow.them, "TAP TO CONTINUE", t - break_t0)
		broadcast.comparison(ci, size, card, flow.state)
		if flow.at_halftime() and not sim:
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
func _venue_pill(ci: Control, size: Vector2, y: float = 30.0) -> void:
	var named := String(Game.match_cfg.get("venue", pool.name))
	if named == "":
		Hud.pill(ci, size, "NEUTRAL SITE", UI.ACCENT, y)
		return
	Hud.pill(ci, size, ("HOME  -  " if Game.match_cfg.get("home", true) else "AWAY  -  ") + named.to_upper(), UI.ACCENT, y)

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
		if sim:
			d.bot(game_dt, sim_keeper, bot_rng)
		elif autoplay:
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
			_vibrate(30)
			excite = 0.8
		"parry":
			_duel_ball(d, Ball.State.LOOSE)
			duel_ball.drift = Vector2(signf(d.from.x - d.goal_x) * randf_range(2.5, 4.0), randf_range(-2.5, 2.5))
			banner.event("save")
			Sfx.play("gasp")
			_vibrate(20)
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
