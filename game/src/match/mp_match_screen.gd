extends Control
## A multiplayer match (see MpMatch). On your attack this works like Quick Match: tap the
## water to pass there, pull the shooting stick back and release to shoot. On theirs you watch it live, frames streamed from their phone. The host's
## "st" messages move both phones through the sprint, attacks, breaks and the shootout.

const HOST_CAP := Color("f2f2e9")    # the host's team wears white, the guest's their club colour
const SLOWMO := 0.6
const END_HOLD := 1.5
const GOAL_HOLD := 2.1
const SPRINT_SEND_MS := 100
const SMOOTH := 14.0                 # how fast watched bodies catch up with the latest frame

var g: MpMatch
var view := PoolView.new()
var aim := AimGuide.new()
var stick := ShotStick.new()   # the shooting stick on the left: the only way you shoot (AimGuide.stick_at)
var calls := CallStrip.new()   # DRIVE▾, your play call
var canvas: Control
var t := 0.0
var break_t0 := 0.0   # t when the quarter break came up (its scoreboard's drop-in)
var excite := 0.0
var autoplay := false
var bot_rng := RandomNumberGenerator.new()
var bot_think := 0.0

var last_key := ""                   # phase + possession we last set up for
var sprint: Sprint = null
var sprint_sent := false
var next_sx := 0
var play: Play = null                # my live attack
var my_clock := 0.0
var swim_in := 0.0
var end_timer := -1.0
var result_sent := false
var counts := {"shots": 0, "saves": 0, "excl": 0}
var shadow: Play = null              # their attack, as seen here
var targets: Array = []              # per shadow body: {pos, facing, arm, dive, out}
var ball_target := {}
var watch_clock := 0.0
var watch_shot := 30.0
var watch_man_up := 0.0
var banner := EventBanner.new()   # every gameplay callout (GOAL!, FOUL!, WIDE!...), one at a time
var buttons: Array = []
var menu_rect := Rect2()
var leaving := false
var duel: KeeperDuel = null          # their shot at your goal: you're the keeper
var duel_seq := -1                   # the possession of the last shot you called
var duel_id := ""                    # "seq:shot" of the last shot you called
var duel_clear := -1.0               # after your call: back to the live picture shortly

func setup(params: Dictionary) -> void:
	autoplay = params.get("autoplay", false)
	bot_rng.seed = 99 + Net.my_id

func _ready() -> void:
	g = Net.game
	if g == null:
		Game.goto("multiplayer")
		return
	canvas = UI.canvas(0, 0, _draw_all)
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.remote_frame.connect(_on_frame)
	g.remote_event.connect(_on_remote_event)
	g.remote_sprint.connect(_on_remote_sprint)
	g.remote_verdict.connect(_on_verdict)
	Net.ended.connect(_on_ended)
	Sfx.music("race")
	Sfx.crowd(0.4)

func _exit_tree() -> void:
	if Net.ended.is_connected(_on_ended):
		Net.ended.disconnect(_on_ended)

# ------------------------------------------------------------------ loop
func _process(dt: float) -> void:
	if g == null:
		return
	t += dt
	excite = maxf(0.0, excite - dt * 0.5)
	view.width = get_viewport_rect().size.x
	view.height = get_viewport_rect().size.y
	var key := "%d:%d" % [g.phase, g.seq]
	if key != last_key:
		last_key = key
		_enter_phase()
	match g.phase:
		MpMatch.Phase.SPRINT:
			_tick_sprint(dt)
		MpMatch.Phase.ATTACK:
			if g.att == g.me:
				_tick_my_attack(dt)
			else:
				_tick_watch(dt)
	stick.layout(get_viewport_rect().size, Vector2.ZERO)
	stick.step(dt, _stick_ready(), aim.stick)
	banner.step(dt)
	canvas.queue_redraw()

func _enter_phase() -> void:
	aim.cancel()
	calls.open = false
	Net.clear_frame()
	play = null
	shadow = null
	duel = null
	end_timer = -1.0
	result_sent = false
	match g.phase:
		MpMatch.Phase.SPRINT:
			sprint = Sprint.new(g.my_team(), g.their_team(), 0.0)
			sprint.remote = true
			sprint.countdown = maxf(0.0, (g.go_at - Net.now_ms()) / 1000.0)
			sprint_sent = false
			banner.clear()
			view.snap_to(sprint.focus())
		MpMatch.Phase.ATTACK:
			if sprint != null:
				var won := g.att == g.me
				sprint.finish(won)
				banner.show("YOUR BALL!" if won else "THEIR BALL!", EventBanner.YELLOW if won else EventBanner.WHITE)
				Sfx.play("good" if won else "miss")
				sprint = null
			else:
				banner.clear()
			if g.is_counter():
				banner.show("COUNTERATTACK!", EventBanner.YELLOW)
			elif g.kind == Play.Kind.PENALTY:
				if g.st.in_shootout:   # (a penalty in play was already called: PENALTY!)
					banner.show("SHOOTOUT!", EventBanner.YELLOW)
				Sfx.play("whistle")
			if g.att != g.me:
				shadow = g.shadow_play()
				targets = []
				ball_target = {}
				watch_clock = g.st.clock
				watch_shot = g.shot0
				view.snap_to(PoolView.attack_focus(shadow.ball.pos))
		MpMatch.Phase.BREAK:
			sprint = null
			break_t0 = t
			Sfx.play("bell")
		MpMatch.Phase.FINAL:
			sprint = null
			Sfx.crowd(0.0)
			var won := g.winner == g.me
			Sfx.music("victory" if won else "")
			Sfx.play("cheer" if won else "miss")
			print(g.result_line())
			Net.match_over(g)

# ------------------------------------------------------------------ sprint
func _tick_sprint(dt: float) -> void:
	if sprint == null:
		return
	var was := sprint.whistled
	sprint.step(dt)
	view.follow(sprint.focus(), dt)
	if sprint.whistled and not was:
		Sfx.play("whistle")
	if autoplay and sprint.started() and int(t * 12.0) % 2 == 0:
		sprint.tap()
	var now := Time.get_ticks_msec()
	if sprint.started() and now >= next_sx:
		next_sx = now + SPRINT_SEND_MS
		Net.send_game({"t": "sx", "x": sprint.progress()}, false)
	if sprint.arrived and not sprint_sent:
		sprint_sent = true
		Net.send_game({"t": "sx", "x": sprint.progress()})
		if g.is_host():
			g.on_sprint(g.me, Net.now_ms())
		else:
			Net.send_game({"t": "spr", "at": Net.now_ms()})

func _on_remote_sprint(x: float) -> void:
	if sprint != null:
		sprint.set_remote(x)

# ------------------------------------------------------------------ my attack
func _tick_my_attack(dt: float) -> void:
	if play == null:
		if Net.now_ms() < g.go_at:
			return
		play = g.new_play()
		play.remote_keeper = true   # their keeper is your friend: shots on target wait for their call
		my_clock = g.start_clock()
		swim_in = g.st.clock - my_clock
		counts = {"shots": 0, "saves": 0, "excl": 0}
		view.snap_to(view.attack_frame(play))
	var scale := SLOWMO if ((aim.active and aim.stick and play.can_throw()) or calls.open) else 1.0
	if play.ball.state == Ball.State.SHOT:
		# every shot at the slow pace of one on target (in step with their dive), wide ones too
		scale = Difficulty.duel_slowmo(Difficulty.MULTIPLAYER)
	if autoplay:
		_bot(dt)
	else:
		_stick_aim()
		play.raise_ball(aim.active and aim.stick and aim.long_enough() and play.can_throw() and play.shooting_pull(aim.target(play.holder)))
	var before := play.elapsed
	play.step(dt * scale)
	if play.kind != Play.Kind.PENALTY:
		my_clock = maxf(0.0, my_clock - (play.elapsed - before) * MatchState.CLOCK_SPEED)
		if my_clock <= 0.0:
			play.buzzer()
	_handle_events()
	view.follow(view.attack_frame(play), dt)
	Net.set_frame(Proto.pack_play(g.seq, my_clock, play))
	if end_timer >= 0.0:
		end_timer -= dt
		if end_timer < 0.0 and not result_sent:
			_send_result()

func _bot(dt: float) -> void:
	bot_think -= dt
	if bot_think > 0.0:
		return
	bot_think = PlayBot.THINK_EVERY
	var d := PlayBot.think(play, bot_rng)
	if not d.is_empty():
		play.throw(d.target, d.power)

func _send_result() -> void:
	result_sent = true
	Net.clear_frame()
	var r := play.result
	var res := {"t": "res", "seq": g.seq, "outcome": String(r.get("outcome", "")), "elapsed": play.elapsed,
		"swim_in": swim_in, "shots": counts.shots, "saves": counts.saves, "excl": counts.excl}
	if r.has("scorer"):
		res["scorer"] = (r.scorer as PoloPlayer).number
	if r.has("assist"):
		res["assist"] = (r.assist as PoloPlayer).number
	if g.is_host():
		g.on_result(g.me, res)
	else:
		Net.send_game(res)

func _handle_events() -> void:
	for e in play.events:
		var k := String(e.k)
		match k:
			"pass":
				Sfx.play("stroke", 1.3, -6.0)
			"catch":
				Sfx.play("touch", 1.1, -8.0)
			"drive":
				banner.show("DRIVE %s!" % CallStrip.LABELS.get(e.side, ""), EventBanner.YELLOW)
			"ball_down":
				Sfx.play("splash", 1.6, -12.0)
			"shot":
				counts.shots += 1
				if float(e.get("catch_shoot", 0.0)) > 0.0:
					Sfx.play("splash", 0.9, 2.5)   # a catch and shoot: a touch heavier
					Game.vibrate(22)
				else:
					Sfx.play("splash")
					Game.vibrate(15)
				_tell({"k": "shot"})
			"save":
				counts.saves += 1
				Sfx.play("gasp")
				_tell({"k": "save"})
			"rebound":
				Sfx.play("turn")
				_rebound(String(e.text))
				_tell({"k": "rebound", "text": e.text})
			"block":
				var by := "BY " + (e.by as PoloPlayer).tag() if e.by != null else ""
				Sfx.play("turn")
				banner.event("block")
				_tell({"k": "block", "sub": by})
			"foul":
				Sfx.play("whistle", 1.15, -5.0)
				banner.event("foul")
				_tell({"k": "foul"})
			"exclusion":
				counts.excl += 1
				Sfx.play("whistle")
				banner.event("exclusion")
				_tell({"k": "exclusion"})
			"duel":
				_tell({"k": "duel", "from": e.from, "cross_y": e.cross_y, "flight": e.flight, "keeper_y": e.keeper_y, "n": e.n,
					"height": e.get("height", 0.5), "on_target": e.get("on_target", true), "strain": e.get("strain", 0.0)})
			"net":
				Sfx.play("splash", 0.7, 1.5)
				Sfx.play("touch", 0.8, -3.0)
				Game.vibrate(25)
			"end":
				_my_end(e)
	play.events.clear()

func _tell(e: Dictionary) -> void:
	var m := e.duplicate()
	m["t"] = "pev"
	m["seq"] = g.seq
	Net.send_game(m)

func _my_end(e: Dictionary) -> void:
	var r := play.result
	end_timer = END_HOLD
	var outcome := String(e.outcome)
	var sub := ""
	if outcome == "goal":
		var scorer: PoloPlayer = r.scorer
		sub = scorer.tag()
		if r.has("assist"):
			sub += "   AST " + (r.assist as PoloPlayer).short_name()
		end_timer = GOAL_HOLD
	elif outcome == "save":
		sub = "BY " + play.keeper.player.tag()
	elif outcome == "steal" and r.get("by") != null:
		sub = "BY " + (r.by as PoloPlayer).tag()
	# a real steal: a defender took it, not the keeper claiming a pass
	var steal: bool = outcome == "steal" and r.get("by") != null and not (r.by as PoloPlayer).is_keeper()
	_end_banner(outcome, String(e.text), sub, true, steal)
	_tell({"k": "end", "outcome": outcome, "text": String(e.text), "sub": sub, "steal": steal})

## Result banners for either side's attack. `mine`: it was my attack.
func _end_banner(outcome: String, text: String, sub: String, mine: bool, steal: bool = false) -> void:
	match outcome:
		"goal":
			banner.event("goal")
			Sfx.play("cheer" if mine else "miss")
			if mine:
				Sfx.play("perfect")   # (the phone buzzes when it hits the net)
			excite = 1.0
			view.shake = 1.0
		"save":
			banner.event("save")
		"miss":
			banner.show("WIDE!")
			Sfx.play("miss" if mine else "good")
		"steal", "turnover":
			if steal:
				banner.event("steal")
			else:
				banner.event("turnover")
			Sfx.play("error" if mine else "good")
		"shotclock":
			banner.show("SHOT CLOCK!", EventBanner.RED)
			Sfx.play("dq")
		"penalty":
			banner.event("penalty")
			Sfx.play("whistle")
		"buzzer":
			banner.show("BUZZER!")
			Sfx.play("bell")

# ------------------------------------------------------------------ their attack
func _on_frame(f: Dictionary) -> void:
	if shadow == null or int(f.seq) != (g.seq & 0xffff):
		return
	var bodies := shadow.bodies()
	if (f.bodies as Array).size() != bodies.size():
		return
	var first := targets.is_empty()
	targets = f.bodies
	ball_target = f.ball
	watch_clock = float(f.clock)
	watch_shot = float(f.shot_clock)
	watch_man_up = float(f.man_up)
	shadow.holder = bodies[int(f.holder)] if int(f.holder) < bodies.size() else null
	if first:
		for i in bodies.size():
			bodies[i].pos = targets[i].pos
		shadow.ball.pos = ball_target.pos

func _tick_watch(dt: float) -> void:
	if shadow == null:
		return
	if duel != null:
		_tick_duel(dt)
	var k := 1.0 - exp(-dt * SMOOTH)
	var bodies := shadow.bodies()
	if targets.size() == bodies.size():
		for i in bodies.size():
			var s: Swimmer = bodies[i]
			if duel != null and s == shadow.keeper:
				continue   # your keeper is yours during the save
			var tg: Dictionary = targets[i]
			var before := s.pos
			s.pos = s.pos.lerp(tg.pos, k)
			s.vel = (s.pos - before) / maxf(dt, 0.001)
			s.anim += dt * (2.0 + s.vel.length() * 3.0)
			s.facing = tg.facing
			s.arm = tg.arm
			s.dive = tg.dive
			s.out = tg.out
	if not ball_target.is_empty() and duel == null:
		shadow.ball.pos = shadow.ball.pos.lerp(ball_target.pos, k)
		shadow.ball.z = lerpf(shadow.ball.z, float(ball_target.z), k)
		shadow.ball.state = int(ball_target.state)
	view.follow(PoolView.attack_focus(shadow.ball.pos), dt)

## Their keeper's call on your shot.
func _on_verdict(outcome: String, seq: int, n: int) -> void:
	if play != null and seq == g.seq:
		play.set_verdict(outcome, n)

func _on_remote_event(e: Dictionary) -> void:
	if g.phase != MpMatch.Phase.ATTACK or g.att == g.me or int(e.get("seq", -1)) != g.seq:
		return
	match String(e.get("k", "")):
		"duel":
			_start_duel(e)
		"shot":
			Sfx.play("splash")
		"save":
			Sfx.play("gasp")
		"rebound":
			Sfx.play("turn")
			_rebound(String(e.get("text", "")))
		"block":
			Sfx.play("turn")
			banner.event("block")
		"foul":
			Sfx.play("whistle", 1.15, -5.0)
			banner.event("foul")
		"exclusion":
			Sfx.play("whistle")
			banner.event("exclusion")
		"end":
			var oc := String(e.get("outcome", ""))
			if duel_seq == g.seq and oc in ["goal", "save", "parry"]:
				return   # you already saw how your dive went
			_end_banner(oc, String(e.get("text", "")), String(e.get("sub", "")), false, bool(e.get("steal", false)))

# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if leaving:
		return
	if event is InputEventScreenTouch:
		var pos: Vector2 = event.position
		if event.pressed:
			if menu_rect.has_point(pos) and g.phase != MpMatch.Phase.FINAL:
				_menu()
			elif g.phase == MpMatch.Phase.ATTACK and play != null and duel == null and not aim.active \
					and calls.press(pos, play) != "":
				pass
			else:
				_press(pos, event.index)
		elif aim.active and event.index == aim.index:
			if event.canceled:
				aim.cancel()   # (the system took the finger: nothing thrown, nothing passed)
			else:
				if aim.stick:
					stick.drag(pos)
					_stick_aim()
				_release()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and aim.active and event.index == aim.index:
		if aim.stick:
			stick.drag(event.position)
		else:
			aim.now = event.position
		get_viewport().set_input_as_handled()

func _press(pos: Vector2, index: int) -> void:
	match g.phase:
		MpMatch.Phase.SPRINT:
			if sprint and sprint.started() and not sprint.arrived:
				sprint.tap()
				Sfx.play("stroke", 1.0 + randf() * 0.2, -4.0)
		MpMatch.Phase.ATTACK:
			if duel != null and not duel.done():
				if duel.can_dive():
					duel.dive(KeeperDive.zone_at_screen(view, pos.y))
					Sfx.play("splash", 1.3, -6.0)
			elif play != null and not aim.active and not play.over:
				# only a touch that comes down on the stick can shoot (match_screen's _press)
				if stick.hit(pos) and _stick_ready():
					aim.begin(index, pos, true)
					stick.take(pos)
				else:
					aim.begin(index, pos)
		MpMatch.Phase.FINAL:
			for b in buttons:
				if (b[0] as Rect2).has_point(pos):
					Sfx.play("click")
					(b[2] as Callable).call()

func _release() -> void:
	var stick_tap := aim.stick and stick.travel < AimGuide.TAP_SLOP and play != null \
		and AimGuide.tap_mate(view, play, aim.start) != null   # (a teammate under the stick: his pass)
	if play != null and aim.stick and aim.long_enough() and play.can_throw():
		play.shoot_at(aim.target(play.holder), aim.power(play.holder))
	elif play != null and (aim.is_tap() or stick_tap):
		var mate := AimGuide.tap_mate(view, play, aim.start)
		var spot = AimGuide.tap_spot(view, aim.start) if not aim.stick else null
		if mate != null and play.pass_to(mate):
			aim.show_mark(play.ball.to, t)
		elif spot != null and play.pass_at(spot):
			aim.show_mark(spot, t)
	aim.cancel()

## The shooting stick is up while you've the ball to shoot with, or your pass is on its way to
## one of yours (match_screen's).
func _stick_ready() -> bool:
	return play != null and g.phase == MpMatch.Phase.ATTACK and duel == null and not play.over and not autoplay \
		and (play.can_throw() or (play.ball.state == Ball.State.PASS and play.ball.receiver != null and play.attackers.has(play.ball.receiver)))

## The stick's knob, as a slingshot pull from wherever the shooter is now (AimGuide.stick_at).
func _stick_aim() -> void:
	if not aim.stick:
		return
	if play == null or play.over or g.phase != MpMatch.Phase.ATTACK:
		aim.cancel()
	elif play.holder != null and play.holder.side == Swimmer.Side.US:
		aim.stick_at(play.holder, ShotStick.target(play.holder.pos, stick.knob))

## No pause in multiplayer: the clock is shared.
func _menu() -> void:
	aim.cancel()
	Game.dialog("MATCH MENU", "The match keeps going while this is open.", [
		["KEEP PLAYING", Callable(), "primary"],
		["LEAVE (FORFEIT)", _leave, "danger"]])

func _leave() -> void:
	leaving = true
	Sfx.crowd(0.0)
	Net.leave()
	Game.goto("multiplayer")

func _on_ended(reason: String) -> void:
	if leaving:
		return
	leaving = true
	Sfx.crowd(0.0)
	Game.dialog("MATCH OVER", reason, [["OK", func(): Game.goto("multiplayer"), "primary"]])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not leaving:
		_menu()

# ------------------------------------------------------------------ drawing
## The host wears light caps (its design may change the colour), the guest dark ones in its
## club colour (its design adds the pattern and trim, never a light base).
func _cap_of(team_i: int) -> Color:
	var host := Caps.base_color(g.designs[0], HOST_CAP)
	return host if team_i == 0 else (g.teams[1] as PoloTeam).cap_against(host)

func _trim_of(team_i: int) -> Color:
	var team_trim: Color = (g.teams[0] as PoloTeam).c1 if team_i == 0 else (g.teams[1] as PoloTeam).trim_against(_cap_of(0))
	return Caps.trim_color(g.designs[team_i], team_trim)

func _draw_all(ci: Control) -> void:
	var size := ci.get_viewport_rect().size
	var net := {}
	if play != null and play.ball.in_net():   # your goal: the net gives (the other phone's shots don't carry it)
		net = {"x": play.ball.net_line, "y": play.ball.pos.y, "t": play.ball.net_t}
	PoolArt.draw_pool(ci, view, t, size, excite, null, 1.0, net)
	var bodies: Array[Swimmer] = []
	var p: Play = null
	if g.phase == MpMatch.Phase.SPRINT and sprint:
		bodies = sprint.bodies()
	elif play != null:
		p = play
	elif shadow != null:
		p = shadow
	if p != null:
		bodies = p.bodies()
	bodies.sort_custom(func(a: Swimmer, b: Swimmer): return a.pos.y < b.pos.y)
	if p == play and p != null and p.can_throw():
		for a in p.attackers:
			if a != p.holder and (p.openness(a) > 1.8 and Geo.range_to_goal(a.pos) < 9.0 \
					or p.center_entry(p.holder.pos, a) == "open"):   # (the centre, his guard on the other side)
				PoolArt.draw_ring(ci, view, a, UI.GOOD)
	var glow := p.catch_glow() if p != null else 0.0
	if glow > 0.0:
		PoolArt.draw_catch_ring(ci, view, p.holder, glow)
	for s in bodies:
		var team_i := _team_of(s)
		HotFire.draw_under(ci, view, s, t)
		PoolArt.draw_body(ci, view, s, PoolArt.CAP_KEEPER if s.keeper else _cap_of(team_i), _trim_of(team_i),
			"" if s.keeper else String(g.designs[team_i]))
		HotFire.draw_over(ci, view, s, t)
	if p != null:
		PoolArt.draw_release_ring(ci, view, p.release_by, p.release_t)
	if g.phase == MpMatch.Phase.SPRINT and sprint and not sprint.done:
		var b := Ball.new()
		b.pos = sprint.ball
		PoolArt.draw_ball(ci, view, b)
	elif p != null:
		PoolArt.draw_shot_power(ci, view, p.ball)
		PoolArt.draw_shot_fx(ci, view, p.ball)
		HotFire.draw_ball_fire(ci, view, p.ball, t, p.holder)
		PoolArt.draw_ball(ci, view, p.ball)
		PoolArt.draw_net_splash(ci, view, p.ball)
		if glow > 0.0:
			PoolArt.draw_catch_glow(ci, view, p.ball, glow)
	if p == play and p != null:
		if p.holder != null and p.holder.side == Swimmer.Side.US and not p.over:
			PoolArt.draw_holder_marker(ci, view, p.holder, t)
		aim.draw(ci, view, p, t)
	_draw_hud(ci, size, p)

func _team_of(s: Swimmer) -> int:
	if g.phase == MpMatch.Phase.SPRINT:
		return g.me if s.side == Swimmer.Side.US else 1 - g.me
	return g.att if s.side == Swimmer.Side.US else 1 - g.att

func _draw_hud(ci: Control, size: Vector2, p: Play) -> void:
	var v := g.my_view()
	if p == play and play != null:
		v.clock = my_clock
	elif p == shadow and shadow != null and not targets.is_empty():
		v.clock = watch_clock
	var tier := Scoreboard.tier()
	var board := Hud.scoreboard(ci, size.x, v, g.my_team(), g.their_team(), _cap_of(g.me), _cap_of(1 - g.me), _trim_of(1 - g.me), {}, tier)
	menu_rect = Rect2(size.x - 24, 3, 20, 19)
	if g.phase != MpMatch.Phase.FINAL:
		Hud.pause_button(ci, menu_rect)
	if p == play and play != null and g.phase == MpMatch.Phase.ATTACK:
		calls.layout(stick.area())
		calls.draw(ci, view, play, t)
	if p != null and g.phase == MpMatch.Phase.ATTACK:
		var sc := play.shot_clock if p == play else watch_shot
		var mu := play.man_up if p == play else watch_man_up
		if g.kind != Play.Kind.PENALTY:
			Scoreboard.shot_clock(ci, tier, board, minf(sc, v.clock))   # (never more than the game clock has left)
		if mu > 0.0 and not p.over:
			Hud.man_up(ci, size.x, mu, p == shadow, Scoreboard.below(board))
		if p == play and play.holder != null and play.holder.side == Swimmer.Side.US:
			Hud.holder_tag(ci, Vector2(3, size.y - 15), play.holder.player)
		if p == play:
			stick.draw(ci, aim.stick)
		if p == shadow:
			UI.text_shadow(ci, Vector2(0, size.y - 6), "%s ATTACKING  -  YOUR AI DEFENDS" % String(g.names[g.att]), 8, Hud.DIM, "caps", HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if g.phase == MpMatch.Phase.SPRINT and sprint:
		if not sprint.started():
			var n := int(ceilf(sprint.countdown / 0.6))
			Hud.banner(ci, size, str(clampi(n, 1, 3)), UI.TEXT, 1.0, "GET READY TO TAP")
		elif not sprint.arrived:
			var pulse := 1.0 if int(t * 8.0) % 2 == 0 else 0.8
			Hud.banner(ci, size, "TAP TAP TAP!", Color(UI.GOLD, pulse), 1.0, "BEAT %s TO THE BALL" % String(g.names[1 - g.me]))
			UI.draw_bar(ci, Rect2(size.x / 2 - 40, size.y - 14, 80, 4), sprint.boost / Sprint.MAX_BOOST, UI.GOOD)
		else:
			Hud.banner(ci, size, "...", UI.TEXT, 1.0, "WAITING FOR THE WHISTLE")
	if g.phase == MpMatch.Phase.ATTACK and Net.now_ms() < g.go_at and banner.is_empty():
		var mine := g.att == g.me
		Hud.banner(ci, size, "YOUR BALL" if mine else "THEIR BALL", UI.GOLD if mine else UI.TEXT, 1.0, "" if mine else "%s IS ATTACKING" % String(g.names[g.att]))
	banner.draw(ci, size)
	match g.phase:
		MpMatch.Phase.BREAK:
			_draw_break(ci, size, v)
		MpMatch.Phase.FINAL:
			_draw_final(ci, size, v)

func _draw_break(ci: Control, size: Vector2, v: MatchState) -> void:
	var left := maxi(0, int(ceilf((g.until - Net.now_ms()) / 1000.0)))
	Hud.break_card(ci, size, v.quarter, v.score, g.my_team(), g.their_team(), "BACK IN THE WATER IN %d" % left, t - break_t0)

func _draw_final(ci: Control, size: Vector2, v: MatchState) -> void:
	var won := g.winner == g.me
	var title := "YOU WIN!" if won else "DEFEAT"
	var fin := Schedule.final_text(v.score, v.shootout if v.in_shootout else [], " - ")
	var lines: Array = [["%s  %s  %s" % [Colleges.short_name(g.my_team()).to_upper(), fin, Colleges.short_name(g.their_team()).to_upper()], UI.GOLD]]
	if g.forfeit:
		lines.append("%s LEFT THE MATCH" % String(g.names[1 - g.winner]))
	lines.append("SHOTS %d - %d    SAVES %d - %d" % [v.shots[0], v.shots[1], v.saves[0], v.saves[1]])
	lines.append("EXCLUSIONS DRAWN %d - %d    STEALS %d - %d" % [v.exclusions[0], v.exclusions[1], v.steals[0], v.steals[1]])
	var wins := ""
	for id in Net.order:
		wins += "%s %d   " % [Net.players[id].name, int(Net.players[id].wins)]
	if wins != "":
		lines.append("WINS  " + wins.strip_edges())
	var r := Hud.card(ci, size, title, UI.GOLD if won else UI.BAD, lines, lines.size(), "", 320.0)
	buttons = []
	if Net.can_start():
		buttons.append([Rect2(r.position.x + r.size.x / 2 - 104, r.end.y + 6, 100, 20), "REMATCH", func(): Net.start_match()])
		buttons.append([Rect2(r.position.x + r.size.x / 2 + 4, r.end.y + 6, 100, 20), "LOBBY", func(): Game.goto("multiplayer")])
	else:
		buttons.append([Rect2(r.position.x + r.size.x / 2 - 50, r.end.y + 6, 100, 20), "LOBBY", func(): Game.goto("multiplayer")])
	for i in buttons.size():
		var b: Rect2 = buttons[i][0]
		var primary := i == 0 and buttons.size() > 1
		ci.draw_rect(b, Color("d98a12") if primary else Color("22407a"))
		ci.draw_rect(b, Color("ffd35c") if primary else Color("5b86d6"), false, 1.0)
		UI.text(ci, b.position + Vector2(0, 13), buttons[i][1], 8, Color("1a1206") if primary else UI.TEXT, "caps", HORIZONTAL_ALIGNMENT_CENTER, b.size.x)

## A loose ball off the keeper or the woodwork: a parry is a save.
func _rebound(text: String) -> void:
	if text == "PARRIED!":
		banner.event("save")
	else:
		banner.show(text)


# ------------------------------------------------------------------ their shot: you're the keeper
## Your friend shot on target: your phone plays the save, with your keeper, and tells
## theirs how it went. Their ball waits at your goal line for the call.
func _start_duel(e: Dictionary) -> void:
	var id := "%d:%d" % [g.seq, int(e.get("n", 0))]
	if shadow == null or duel_id == id:
		return
	duel_id = id
	duel_seq = g.seq
	duel_clear = -1.0
	var from: Vector2 = e.get("from", Vector2(Geo.GOAL_X - 5.0, Geo.GOAL_Y))
	duel = KeeperDuel.new().setup_given(shadow.keeper.player, from, float(e.cross_y), float(e.flight),
		Geo.GOAL_X, float(e.get("keeper_y", Geo.GOAL_Y)), Difficulty.MULTIPLAYER, float(e.get("height", 0.5)), bool(e.get("on_target", true)),
		float(e.get("strain", 0.0)))
	duel.home = g.is_host()   # the host's team is the home team
	shadow.ball.pos = from
	Sfx.play("splash")

func _tick_duel(dt: float) -> void:
	if duel.done():
		duel.settle(dt)
		shadow.keeper.pos.y = duel.keeper_y
		shadow.keeper.pose = duel.anim if duel.anim != null and not duel.anim.done() else null
		if duel.outcome == "save":
			shadow.ball.secure_t += dt
			shadow.ball.put(Play.held_at(shadow.keeper))   # in his hands, wherever his dive takes them
		if duel_clear >= 0.0:
			duel_clear -= dt
			if duel_clear < 0.0:
				duel = null   # back to the live frames (a rebound can lead to another shot)
				shadow.keeper.pose = null
		return
	var game_dt := dt * duel.slowmo
	if autoplay:
		duel.bot(game_dt, 0.6, bot_rng)
	duel.step(game_dt)
	shadow.keeper.pos.y = duel.keeper_y
	shadow.keeper.pose = duel.anim
	shadow.ball.pos = duel.ball_pos()
	shadow.ball.z = duel.ball_z()
	shadow.ball.state = Ball.State.SHOT
	if duel.done():
		Net.send_game({"t": "kv", "seq": g.seq, "outcome": duel.outcome, "n": int(duel_id.get_slice(":", 1))})
		duel_clear = 0.8
		if duel.outcome == "save":
			shadow.keeper.arm = 1.0
			shadow.ball.secure()
		match duel.outcome:
			"goal":
				banner.event("goal")
				Sfx.play("miss")
				excite = 1.0
			"save":
				banner.event("save")
				Sfx.play("cheer")
				Game.vibrate(30)
			"parry":
				banner.event("save")
				Sfx.play("gasp")
