extends "res://src/ui/screens/play_lab.gd"
## Developer Mode's TEST IN GAME (DEV RECRUITS > a DEV Recruit): the DEV Recruit in a real
## possession (Play, run and drawn exactly as play_lab runs every lab: the match's own code), his
## real attributes (a fresh copy, DevRecruits.make: nobody's), in his own cap and sprite. You play
## the attack as in a match (the stick shoots, a tap passes); nothing is scripted to succeed.
##   LOGAN  PERIMETER SHOT  the ball to him at the point, an all-5 keeper
##          ELITE KEEPER    ...the same, an all-10 keeper
##          CONTESTED       their 4-5 drop: he's at 5 and their piston comes out on him
##          OPEN LOOK       at the point, his guard giving him room (back_off, as after a foul)
##   BLAKE  CENTER DEFENSE  he guards your centre; feed the 2 m and beat him if you can
##          STRONG CENTER   ...your centre an all-10-Strength wrestler
##          SHOT BLOCK      their 4-5 drop: he's the piston coming out on your 5, who has the ball
##          PASSING LANE    he guards your 4; the ball's at your point
## COMPARE TO 10/10: the same scenario and seed with the boosted attribute set to 10 on the copy
## (DEV / DFN 10; DEV / SHO 10), everything else identical. RESET replays the
## same seed; NEW SEED moves on. RUN TRIALS plays the scenario TRIALS times for both (seeds
## 1..TRIALS, the same seed for both sides of each pair) with one fixed action (Logan shoots at
## alternate corners; Blake's attack shoots through him, feeds the centre or passes past him) and
## tallies what the engine made of it. Nothing is counted or saved: no career, player, XP or stat.

const DEV_ID := 990002
const SCENARIOS := {
	"blake": [["CENTER DEFENSE", "centre"], ["STRONG CENTER", "strong"], ["SHOT BLOCK", "block"], ["PASSING LANE", "lane"]],
	"logan": [["PERIMETER SHOT", "perimeter"], ["ELITE KEEPER", "keeper"], ["CONTESTED", "contested"], ["OPEN LOOK", "open"]],
}
## The copy's attributes for each comparison: [label, {attr: value}] ({}: his own).
const VARIANTS := {
	"blake": [["DEV DFN 15", {}], ["DFN 10", {"dfn": 10.0}]],
	"logan": [["DEV 14", {}], ["SHO 10", {"sho": 10.0}]],
}
const FIRST_SEED := 31
const SETTLE := 1.2            # s the defence sets up (the ball held) before it's live for you
const STEP := 1.0 / 60.0
const TRIALS := 30
const TRIAL_MAX := 7.0         # s a trial is watched at most after its action
const AIM_OFF := 0.95          # the trials' aim, off the middle of the goal (AttrBench.SHOT_AIM)
const POWER := 0.8             # ...and pull
const OPEN_ROOM := 4.0         # s his guard gives OPEN LOOK room
const CENTRE_SHOOT := 0.5      # s after the centre's catch, the trial's centre shoots

var key := "logan"
var scen := ""
var variant := 0
var seed_v := FIRST_SEED
var me: Swimmer = null         # the DEV Recruit's swimmer
var last_result := ""
var trial_busy := false
var row_s: HBoxContainer
var row_v: HBoxContainer
var trials_btn: Button

func setup(params: Dictionary) -> void:
	key = String(params.get("key", "logan"))
	if not DevRecruits.DEFS.has(key):
		key = "logan"

func _ready() -> void:
	aims = true
	lab_ready("TEST IN GAME  %s" % DevRecruits.full_name(key))
	scen = String(SCENARIOS[key][0][1])
	row_s = UI.hbox(3)
	row_s.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row_s)
	row_v = UI.hbox(3)
	row_v.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row_v)
	_buttons()
	_load.call_deferred()

func on_back() -> void:
	Sfx.play("back")
	Game.goto("dev_lab", {"keep": true}, false)

func _buttons() -> void:
	for row in [row_s, row_v]:
		for ch in row.get_children():
			row.remove_child(ch)
			ch.queue_free()
	for s in SCENARIOS[key]:
		var id := String(s[1])
		var b := UI.button(String(s[0]), func():
			scen = id
			Sfx.play("click")
			_buttons()
			_load(), "tab_on" if id == scen else "tab", 0, 18)
		b.name = "Scen_" + id
		row_s.add_child(b)
	var lead := UI.label("COMPARE TO 10/10:", 8, UI.DIM, "caps")
	lead.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row_v.add_child(lead)
	for i in (VARIANTS[key] as Array).size():
		var n := i
		var b := UI.button(String(VARIANTS[key][i][0]), func():
			variant = n
			Sfx.play("click")
			_buttons()
			_load(), "tab_on" if i == variant else "tab", 0, 18)
		b.name = "Var_%d" % i
		row_v.add_child(b)
	var rs := UI.button("RESET", func(): _load(), "ghost", 0, 18)
	rs.name = "Reset"
	rs.tooltip_text = "The same scenario on the same seed"
	row_v.add_child(rs)
	var ns := UI.button("NEW SEED", func():
		seed_v += 1
		_load(), "ghost", 0, 18)
	ns.name = "NewSeed"
	row_v.add_child(ns)
	trials_btn = UI.button("RUNNING..." if trial_busy else "RUN %d TRIALS" % TRIALS, run_trials, "primary", 0, 18)
	trials_btn.name = "RunTrials"
	trials_btn.disabled = trial_busy
	trials_btn.tooltip_text = "DEV against %s, the same seeds for both" % String(VARIANTS[key][_cmp_variant()][0])
	row_v.add_child(trials_btn)

## The comparison RUN TRIALS sets against his own: the picked one, or the first 10/10 one.
func _cmp_variant() -> int:
	return variant if variant > 0 else 1

# ------------------------------------------------------------------ building a test
## A fresh copy of DEV Recruit `key` with `over` ({attr: value}) on it and nothing else changed
## (his ceiling with it: a valid record). Nobody's, never saved.
static func subject_player(k: String, over: Dictionary) -> PoloPlayer:
	var p := DevRecruits.make(k, DEV_ID)
	for a in over:
		p.attrs[a] = float(over[a])
		p.attr_pot[a] = float(over[a])
	Attributes.sync(p)
	return p

## `p` in swimmer `s`'s place, at his own speed (Swimmer's own formula).
static func put(s: Swimmer, p: PoloPlayer) -> void:
	s.player = p
	s.top_speed = Swimmer.new(p, s.side, s.keeper).top_speed

static func marker(play: Play, a: Swimmer) -> Swimmer:
	for d in play.defenders:
		if d.mark == a:
			return d
	return null

static func _run(play: Play, secs: float) -> void:
	var left := secs
	while left > 0.0 and not play.over:
		play.step(STEP)
		play.events.clear()
		left -= STEP

## Scenario `sc` for DEV Recruit `k` (his attributes with `over` on them) on seed `sv`: two
## made-up League clubs (fresh every time), him put in his place, the defence set, the ball live
## with `holder`. {ok, play, me (his swimmer), holder, mate (the pass's man, if any)}.
static func build_test(k: String, sc: String, over: Dictionary, sv: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = sv
	var play := Play.new(League.make_team(2, 1), League.make_team(3, 1), Play.Kind.HALF_COURT, rng)
	var subj := subject_player(k, over)
	var out := {"ok": true, "play": play}
	var first: Swimmer = null
	match sc:
		"perimeter", "keeper", "open":
			var a := DefenseFormation.by_tag(play.attackers, "3")
			put(a, subj)
			out.me = a
			out.holder = a
			if sc == "keeper":
				put(play.keeper, AttrBench.player({"com": 10.0, "lun": 10.0, "blk": 10.0, "leg": 10.0}, true))
		"contested", "block":
			play.instant_drop(DefenseFormation.F.FOUR_FIVE)
			var tag := DefenseFormation.slot(play, "5")
			var a := DefenseFormation.by_tag(play.attackers, tag)
			var pr := DefenseFormation.by_tag(play.defenders, tag, true)
			if sc == "contested":
				put(a, subj)
				out.me = a
			else:
				put(pr, subj)
				out.me = pr
			out.holder = a
			first = DefenseFormation.by_tag(play.attackers, DefenseFormation.slot(play, "2"))
		"centre", "strong":
			var c := DefenseFormation.by_tag(play.attackers, "C")
			var g := marker(play, c)
			put(g, subj)
			if sc == "strong":
				put(c, AttrBench.player({"str": 10.0, "sho": 7.0, "pas": 6.0, "dfn": 6.0}, false, {}, PoloPlayer.Pos.CENTER))
			out.me = g
			out.mate = c
			out.holder = DefenseFormation.by_tag(play.attackers, "3")
		"lane":
			var r := DefenseFormation.by_tag(play.attackers, "4")
			put(marker(play, r), subj)
			out.me = marker(play, r)
			out.mate = r
			out.holder = DefenseFormation.by_tag(play.attackers, "3")
	play.give_ball(first if first != null else out.holder)
	_run(play, SETTLE)
	if play.over:
		out.ok = false
		return out
	play.give_ball(out.holder)
	play.free_throw = false   # (a whistle while it set up: this is a new ball, not a free throw)
	play.shot_clock = Play.SHOT_CLOCK
	if sc == "open":
		var d := play.on_ball_guard(out.holder)
		if d == null:
			d = marker(play, out.holder)
		if d != null:
			d.back_off = OPEN_ROOM
	play.events.clear()
	return out

## The scenario as it stands (scen, variant, seed_v), live in the pool.
func _load() -> void:
	var b := build_test(key, scen, VARIANTS[key][variant][1], seed_v)
	_end_show()
	banner.clear()
	aim.cancel()
	play = b.play
	play.bar_fx = true
	play.bar_mode = BarHit.override
	me = b.get("me")
	end_t = -1.0
	paused = false
	view.width = maxf(stage_cv.size.x, 120.0)
	view.height = maxf(stage_cv.size.y, 80.0)
	view.zoom_to = 1.0
	view.zoom = 1.0
	view.snap_to(view.attack_frame(play))
	if not bool(b.ok):
		last_result = "COULDN'T SET IT UP ON THIS SEED: TRY NEW SEED"

## After a result: the same test again, ready (RESET's seed).
func settled() -> void:
	if play != null and play.over:
		last_result = String(play.result.get("text", play.result.get("outcome", ""))).to_upper()
		_load()

func lab_tick(_dt: float) -> void:
	var v: Array = VARIANTS[key][variant]
	status = "%s  %s  SEED %d%s" % [String(v[0]), _scen_name(), seed_v, ("   LAST: " + last_result) if last_result != "" else ""]

func _scen_name() -> String:
	for s in SCENARIOS[key]:
		if String(s[1]) == scen:
			return String(s[0])
	return scen

## A ring on him, the DEV Recruit, in his own colours (his cap and sprite as in a match).
func lab_draw(ci: Control) -> void:
	if me != null and not me.out:
		PoolArt.draw_ring(ci, view, me, DevArt.CYAN)

# ------------------------------------------------------------------ RUN TRIALS
## One trial: scenario `sc` on seed `sv` with `over`, its one fixed action, and what came of it
## (a category name; "VOID" if the seed couldn't set it up).
static func trial(k: String, sc: String, over: Dictionary, sv: int) -> String:
	var b := build_test(k, sc, over, sv)
	if not bool(b.ok):
		return "VOID"
	var play: Play = b.play
	var target := Vector2(Geo.GOAL_X, Geo.GOAL_Y + (AIM_OFF if sv % 2 == 0 else -AIM_OFF))
	var shooting := sc in ["perimeter", "keeper", "contested", "open", "block"]
	if sc == "block":
		var me_s: Swimmer = b.me
		var wait := 2.0
		while wait > 0.0 and not play.over and me_s.press != DefenseFormation.Press.BLOCK:
			play.step(STEP)
			play.events.clear()
			wait -= STEP
		if play.over or play.holder != b.holder:
			return "VOID"
	if shooting:
		if play.shoot_at(target, POWER) != "shot":
			return "VOID"
	else:
		if not play.pass_to(b.mate):
			return "VOID"
	var f := {}
	var caught_t := -1.0
	var t := 0.0
	while t < TRIAL_MAX and not play.over:
		play.step(STEP)
		t += STEP
		for e in play.events:
			match String(e.k):
				"tip", "block", "exclusion", "penalty":
					f[String(e.k)] = true
				"challenge":
					if bool(e.get("won", false)):
						f["won"] = true
				"catch":
					if b.has("mate") and String(e.get("tag", "")) == (b.mate as Swimmer).tag and caught_t < 0.0:
						caught_t = t
		play.events.clear()
		if play.holder != null and play.holder.side == Swimmer.Side.THEM:
			f["lost"] = true
			break
		if sc == "lane" and caught_t >= 0.0:
			return "PASS CAUGHT"
		if sc in ["centre", "strong"] and caught_t >= 0.0 and t - caught_t >= CENTRE_SHOOT and play.holder == b.mate and not f.has("shot"):
			f["shot"] = true
			play.shoot_at(target, POWER)
	var outcome := String(play.result.get("outcome", "")) if play.over else ""
	if sc == "lane":
		return "PICKED OFF / TIPPED" if f.has("tip") or f.has("lost") or outcome in ["turnover", "steal"] else "OTHER"
	if sc in ["centre", "strong"]:
		if caught_t < 0.0:
			return "ENTRY STOPPED" if f.has("tip") or f.has("lost") or outcome in ["turnover", "steal"] else "OTHER"
		if f.has("exclusion") or f.has("penalty"):
			return "CENTRE DREW EXCLUSION / PENALTY"
		if f.has("won") or f.has("lost") or outcome in ["turnover", "steal"]:
			return "GUARD WON THE BALL"
		if outcome == "goal":
			return "CENTRE SCORED"
		if outcome in ["save", "miss"] or f.has("block"):
			return "CENTRE SHOT STOPPED"
		return "OTHER"
	if f.has("block"):
		return "BLOCKED"
	match outcome:
		"goal":
			return "GOAL"
		"save":
			return "SAVED"
		"miss":
			return "MISSED"
		"penalty":
			return "PENALTY DRAWN"
	return "OTHER"

## RUN TRIALS: his own attributes against the comparison, TRIALS pairs on the same seeds, a few a
## frame, then the tallies. {dev: {category: n}, cmp: {...}, n}.
func run_trials() -> Dictionary:
	if trial_busy:
		return {}
	trial_busy = true
	_buttons()
	var cv := _cmp_variant()
	var out := {"dev": {}, "cmp": {}, "n": TRIALS, "cmp_name": String(VARIANTS[key][cv][0]), "dev_name": String(VARIANTS[key][0][0])}
	for i in TRIALS:
		var sv := i + 1
		for side in ["dev", "cmp"]:
			var over: Dictionary = VARIANTS[key][0][1] if side == "dev" else VARIANTS[key][cv][1]
			var r := trial(key, scen, over, sv)
			out[side][r] = int(out[side].get(r, 0)) + 1
		if i % 3 == 2 and is_inside_tree():
			await get_tree().process_frame
	trial_busy = false
	if is_inside_tree():
		_buttons()
		Game.dialog("%s: %d TRIALS" % [_scen_name(), TRIALS], trial_text(out), [["OK", Callable(), "primary"]])
	return out

## The tallies, side by side: each category, his own and the comparison's count and share.
static func trial_text(out: Dictionary) -> String:
	var cats: Array = []
	for side in ["dev", "cmp"]:
		for k in out[side]:
			if not k in cats:
				cats.append(k)
	cats.sort()
	var lines: Array = ["%s  vs  %s  (seeds 1-%d, the same for both)" % [out.dev_name, out.cmp_name, int(out.n)]]
	for k in cats:
		var a := int(out.dev.get(k, 0))
		var b := int(out.cmp.get(k, 0))
		lines.append("%s:  %d (%d%%)  vs  %d (%d%%)" % [k, a, roundi(100.0 * a / float(out.n)), b, roundi(100.0 * b / float(out.n))])
	lines.append("Real engine, one fixed action per trial; small samples vary. Nothing saved.")
	return "\n".join(lines)
