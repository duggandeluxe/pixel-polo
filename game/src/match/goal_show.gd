class_name GoalShow
extends RefCounted
## A goal's moment, about 2.5 s from the ball crossing the line to the next possession (less
## in a shootout, a little more for the big ones), over the match screen:
##   DETECTED     0 - 0.25 s  the ball carries on into the net (Ball.into_net) and the net gives
##                            where it hit (PoolArt.draw_goal); spray off the line, the play
##                            slowed for a beat (time_scale)
##   IMPACT       - 0.65 s    GOAL! bursts in big, overshoots and settles, a flash behind it,
##                            a shake, the camera pushes in on the goal; the goal sting
##   CELEBRATION  - 1.7 s     the scorer and his goals today, his fist up, a bounce or two and
##                            a splash, his mates turning to him; the beaten keeper's arms drop.
##                            TIE GAME! / GAME WINNER! take over the word, TAKES THE LEAD! under it
##   SCOREBOARD   - 2.2 s     the scorer's number goes up on the board (board_fx)
##   TRANSITION   - 2.6 s     everything fades, the camera eases back out
## A tap once DETECTED is over skips the rest (can_skip): the screen ends the possession at
## once. The show only draws and times: it's started by the play's own "end" (or their
## shootout duel's goal), and the goal is counted once, by MatchFlow, when the screen's end
## timer runs out (the board shows the new number a moment before that). The game clock is
## already stopped: it only runs while the ball is live.

enum Stage { NONE, DETECTED, IMPACT, CELEBRATION, SCOREBOARD, TRANSITION }

const IMPACT_AT := 0.25          # GOAL! comes in...
const CELEBRATE_AT := 0.65       # ...and has settled: the scorer's name, his fist up
const CELEBRATE := 1.05          # how long the celebration holds...
const SHOOTOUT_CELEBRATE := 0.45 # ...in a shootout, a quick one
const LATE_EXTRA := 0.25         # a big goal late in the 4th: a little longer...
const WINNER_EXTRA := 0.4        # ...and the game winner longer still
const BOARD := 0.5               # the scoreboard going up
const OUT := 0.4                 # the fade back to play
const LATE_CLOCK := 60.0         # game-clock seconds left in the 4th that make it "late" (as Play.clutch)
const HIT_STOP := 0.16           # the play runs at HIT_STOP_SLOW this long after the goal
const HIT_STOP_SLOW := 0.3
const ZOOM := 1.06               # the camera's push in on the goal...
const BIG_ZOOM := 1.1            # ...for a late goal or the winner
const MATE_R := 4.5              # m: teammates this close to the scorer join in
const HOP_HZ := 1.6              # the scorer's bounces a second...
const HOP_PX := 4.0              # ...and how high (px)
const SWAP_AT := 0.35            # s into the celebration: TIE GAME! / GAME WINNER! / TAKES THE LEAD!
const TEXT_TOP := 44.0           # px: the top of the headline strip (under the scoreboard)
const WORD := 40                 # the headline's font size (WORD_BIG for the big ones)
const WORD_BIG := 46
const YELLOW := Color("ffd83d")  # EventBanner.YELLOW
const OUTLINE := Color("0b2057") # Hud.PANEL_BG
const SPRAY := 0.35              # s the spray off the goal line lasts

var stage: int = Stage.NONE
var t := 0.0                     # seconds since the goal
var side := 0                    # 0 your goal, 1 theirs
var scorer: PoloPlayer = null    # null: GOAL! and nothing made up
var goals_today := 0             # his goals in play today, this one too (0 in a shootout)
var kind := ""                   # "", "tie", "lead" or "winner" (classify)
var late := false
var shootout := false
var team := ""                   # the scoring team's short name (TAKES THE LEAD!)
var team_col := Color.WHITE      # its caps, flashed on the scoreboard
var celebrate := CELEBRATE
var mouth := Vector2.ZERO        # where it crossed the goal line (pool metres)
var hero: Swimmer = null         # the scorer in the water
var mates: Array[Swimmer] = []   # his teammates near enough to join in
var keeper: Swimmer = null       # the keeper it went past
var top := -1.0                  # px: where the text block sits (place), once it's drawn
var hop_boost := 1.0             # how big the scorer's bounces are (a celebration's: Celebrations)
var word_add := 0                # GOAL! this much bigger (the Goal Celebrations level: GoalFx)
var pre := 0.0                   # s held back before it starts (a BAR-IN! / BAR-DOWN! first: BarHit.PRE)

## What a goal for `side` means, from the score before it's counted: {kind, late}.
## "winner" only when the rules end the game on it: in play, a goal at the final buzzer (a shot
## in the air at 0:00 still counts) that leaves the scorer ahead; in a shootout, the penalty
## that settles it (`decides`, MatchFlow.their_penalty_wins). "tie": it levels the game; "lead":
## it breaks a tie. `late`: in the last LATE_CLOCK of the 4th with a goal in it either way.
static func classify(st: MatchState, p_side: int, decides: bool = false) -> Dictionary:
	if st.in_shootout:
		return {"kind": "winner" if decides else "", "late": false}
	var mine: int = int(st.score[p_side]) + 1
	var theirs: int = int(st.score[1 - p_side])
	var k := ""
	if st.is_last_quarter() and st.quarter_over() and mine > theirs:
		k = "winner"
	elif mine == theirs:
		k = "tie"
	elif mine == theirs + 1:
		k = "lead"
	var lt := st.is_last_quarter() and st.clock <= LATE_CLOCK and absi(mine - theirs) <= 1
	return {"kind": k, "late": lt or k == "winner"}

## The goal's in: the show starts. `at`: where it crossed the line.
## `p_pre`: seconds to hold it back (t starts at -p_pre), counted in total().
func start(p_side: int, who: PoloPlayer, st: MatchState, p_team: String, col: Color, at: Vector2,
		decides: bool = false, p_pre: float = 0.0) -> void:
	clear()
	pre = maxf(0.0, p_pre)
	t = -pre
	side = p_side
	scorer = who
	team = p_team
	team_col = col
	mouth = at
	shootout = st.in_shootout
	var c := classify(st, side, decides)
	kind = String(c.kind)
	late = bool(c.late)
	goals_today = 0 if shootout or who == null else (st.goal_by[side] as Array).count(who) + 1
	celebrate = SHOOTOUT_CELEBRATE if shootout else CELEBRATE + (LATE_EXTRA if late else 0.0) \
		+ (WINNER_EXTRA if kind == "winner" else 0.0)
	stage = Stage.DETECTED

## Who's in it: the scorer, the teammates who can join in (only those within MATE_R of him), and
## the keeper beaten. Any of them can be null / empty.
func cast(p_hero: Swimmer, p_mates: Array, p_keeper: Swimmer) -> void:
	hero = p_hero
	keeper = p_keeper
	mates.clear()
	for m: Swimmer in p_mates:
		if m != null and m != hero and not m.keeper and not m.out and hero != null \
				and m.pos.distance_to(hero.pos) <= MATE_R:
			mates.append(m)

## Over (or skipped): everybody back to normal.
func clear() -> void:
	for s in _bodies():
		s.cheer = 0.0
		s.cheer_style = ""
		s.hop = 0.0
		s.slump = 0.0
	hop_boost = 1.0
	stage = Stage.NONE
	t = 0.0
	pre = 0.0
	top = -1.0
	hero = null
	keeper = null
	mates.clear()

func active() -> bool:
	return stage != Stage.NONE

func big() -> bool:
	return late or kind == "winner"

func board_at() -> float:
	return CELEBRATE_AT + celebrate

func out_at() -> float:
	return board_at() + BOARD

## The whole show, seconds: the screen holds the possession's end this long.
func total() -> float:
	return pre + out_at() + OUT

## A tap skips the rest, once the ball's in.
func can_skip() -> bool:
	return active() and t >= IMPACT_AT

## The play's speed: slowed right after the goal, for the hit.
func time_scale() -> float:
	return HIT_STOP_SLOW if active() and t >= 0.0 and t < HIT_STOP else 1.0

func stage_at(s: float) -> int:
	if s < IMPACT_AT:
		return Stage.DETECTED
	if s < CELEBRATE_AT:
		return Stage.IMPACT
	if s < board_at():
		return Stage.CELEBRATION
	if s < out_at():
		return Stage.SCOREBOARD
	return Stage.TRANSITION

## One frame (`dt` real seconds). `view`: the camera, for the shake.
func step(dt: float, view: PoolView = null) -> void:
	if not active():
		return
	t += dt
	var now := stage_at(t)
	while stage < now:
		stage += 1
		_enter(stage, view)
	_animate(dt)

func _enter(s: int, view: PoolView) -> void:
	match s:
		Stage.IMPACT:
			if side == 0:
				Sfx.play("goal")
				Sfx.play("cheer")
				Game.vibrate(30)
			else:
				Sfx.play("goal", 0.9, -6.0)   # theirs: the same sting, lower and quieter
			if view != null:
				view.shake = maxf(view.shake, 1.25 if big() else 0.9)
		Stage.CELEBRATION:
			if hero != null:
				Sfx.play("splash", 1.4, -9.0)
		Stage.SCOREBOARD:
			Sfx.play("score_tick", 1.12 if kind in ["tie", "winner"] else 1.0)

## The bodies: the scorer's fist and bounces, his mates', the keeper's arms down as he
## drifts back to the middle of his goal.
func _animate(dt: float) -> void:
	var c := t - CELEBRATE_AT
	if hero != null:
		hero.cheer = 1.0 if c >= -0.1 and t < out_at() + 0.15 else 0.0
		hero.hop = HOP_PX * hop_boost * hop_at(c, hops())
	for m in mates:
		m.cheer = 1.0 if c >= 0.1 and c < 0.8 else 0.0
		m.hop = HOP_PX * 0.5 * hop_at(c - 0.15, 1)
		if hero != null and absf(hero.pos.x - m.pos.x) > 0.3:
			m.facing = signf(hero.pos.x - m.pos.x)   # turned to the scorer
	if keeper != null:
		keeper.slump = 1.0 if t >= IMPACT_AT and t < out_at() else 0.0
		if t >= 0.0 and (keeper.pose == null or keeper.pose.done()):   # (still through a BAR-IN!'s hit-stop)
			keeper.pos.y = move_toward(keeper.pos.y, Geo.GOAL_Y, 0.8 * dt)
			keeper.target = keeper.pos

## How many times the scorer bounces.
func hops() -> int:
	if shootout:
		return 1
	return 3 if kind == "winner" else 2

## 0..1, how far up a bounce is `c` seconds into the celebration (`n` bounces, then still).
static func hop_at(c: float, n: int) -> float:
	if c < 0.0 or c > (n - 0.5) / HOP_HZ:
		return 0.0
	return maxf(0.0, sin(c * TAU * HOP_HZ))

# ------------------------------------------------------------------ camera
## Where the camera looks: in on the goal mouth with the scorer kept in shot.
func focus() -> Vector2:
	var at := hero.pos if hero != null else mouth
	return mouth.lerp(at, 0.5)

func zoom() -> float:
	if not active() or stage == Stage.TRANSITION or t < IMPACT_AT * 0.5:
		return 1.0
	return BIG_ZOOM if big() else ZOOM

# ------------------------------------------------------------------ the board
## For Hud.scoreboard: once SCOREBOARD's on, the scorer's side one up, pulsing.
func board_fx() -> Dictionary:
	if not active() or t < board_at():
		return {}
	return {"side": side, "add": 1, "t": t - board_at(), "col": team_col, "big": kind in ["tie", "winner"]}

# ------------------------------------------------------------------ drawing
## In the pool, over the bodies: the spray off the line and the splash under each bounce.
func draw_world(ci: CanvasItem, v: PoolView) -> void:
	if not active():
		return
	if t >= 0.0 and t < SPRAY:
		var u := t / SPRAY
		var p := v.to_screen(mouth, 0.2)
		var away := -1.0 if v.to_screen(mouth).x > v.width * 0.5 else 1.0   # back out of the goal, on screen
		for i in 7:
			var dx := (6.0 + 9.0 * (i % 4)) * away * (1.0 if i % 2 == 0 else 0.55)
			var dy := 26.0 + 8.0 * (i % 3)
			var q := p + Vector2(dx * u * 1.6, -dy * u + 70.0 * u * u) + Vector2(0, (i % 3) - 1)
			ci.draw_rect(Rect2(roundf(q.x), roundf(q.y), 2 if i % 3 == 0 else 1, 1), Color(1, 1, 1, 0.9 * (1.0 - u)))
	if hero == null:
		return
	var c := t - CELEBRATE_AT
	var lands: Array[float] = [0.0]   # the fist going up, then each bounce landing
	for n in hops():
		lands.append((n + 0.5) / HOP_HZ)
	for l in lands:
		var age := c - l
		if age >= 0.0 and age < 0.3:
			_splash(ci, v.to_screen(hero.pos), age / 0.3)

## A small pixel splash on the waterline at `p`, `u` 0..1 through it.
static func _splash(ci: CanvasItem, p: Vector2, u: float) -> void:
	var a := 1.0 - u
	var w := roundf(6.0 + 8.0 * u)
	ci.draw_rect(Rect2(p.x - w, p.y + 2, 2.0 * w, 1), Color(UI.WATER_SHINE, 0.8 * a))
	for d in [Vector2(-7, -5), Vector2(-4, -8), Vector2(4, -8), Vector2(7, -5), Vector2(0, -10)]:
		var q := p + Vector2(d.x * (0.6 + u), d.y * (0.5 + u) + 18.0 * u * u)
		ci.draw_rect(Rect2(roundf(q.x), roundf(q.y), 1, 2 if d.x == 0.0 else 1), Color(1, 1, 1, 0.85 * a))

## Over the HUD: the strip, the flash, the word, the scorer and his goals today, the extras.
## `v`: the camera, to keep the block off the scorer (place).
func draw(ci: CanvasItem, size: Vector2, v: PoolView = null) -> void:
	if not active() or t < IMPACT_AT:
		return
	if top < 0.0:
		top = place(size, v)   # (once: the block doesn't jump about)
	var a := 1.0 - clampf((t - out_at()) / OUT, 0.0, 1.0)
	var u := t - IMPACT_AT
	var c := t - CELEBRATE_AT
	var base := word_base()
	var cap := roundf(base * 0.55)
	var cy := top + 8.0 + cap * 0.5   # the word's middle
	var info := _lines()
	# the strip, as wide as what's on it: opens out behind the word, then down over the scorer's lines
	var open := 1.0 - pow(1.0 - clampf(u / 0.1, 0.0, 1.0), 2.0)
	var h := cap + 16.0
	if c >= 0.0 and not info.is_empty():
		h += lerpf(0.0, 10.0 + 12.0 * info.size(), clampf(c / 0.12, 0.0, 1.0))
	var sw := roundf(minf(size.x, content_w(size.x) + 36.0) * lerpf(0.6, 1.0, open))
	var strip := Rect2(roundf((size.x - sw) / 2.0), top, sw, roundf(h * lerpf(0.5, 1.0, open)))
	ci.draw_rect(strip, Color(OUTLINE, 0.82 * a))
	ci.draw_rect(Rect2(strip.position.x, strip.position.y, strip.size.x, 1), Color(YELLOW, 0.9 * a))
	ci.draw_rect(Rect2(strip.position.x, strip.end.y - 1, strip.size.x, 1), Color(YELLOW, 0.9 * a))
	# the flash behind the word: white, then yellow, gone in a blink
	if u < 0.16:
		var f := u / 0.16
		var fc := Color.WHITE.lerp(YELLOW, f)
		var fw := roundf(sw * lerpf(0.75, 1.05, f))
		ci.draw_rect(Rect2(roundf((size.x - fw) / 2.0), roundf(cy - cap * 0.5 - 6.0), fw, cap + 12.0), Color(fc, 0.75 * (1.0 - f)))
	# the word: GOAL!, then TIE GAME! / GAME WINNER! punching in over it
	var word := "GOAL!"
	var pop := punch(u)
	var swap := headline_swap()
	if swap != "" and c >= SWAP_AT:
		word = swap
		pop = punch(c - SWAP_AT + 0.06)   # (a smaller punch: it starts part way)
	_outlined(ci, size, word, word_size(word, base, pop, size.x), cy, Color(YELLOW, a))
	# the scorer, his goals today, TAKES THE LEAD!
	if c < 0.0:
		return
	var la := a * clampf(c / 0.1, 0.0, 1.0)
	var y := top + cap + 16.0 + 12.0 - roundf(4.0 * (1.0 - clampf(c / 0.1, 0.0, 1.0)))
	for l: Array in info:
		var sz: int = l[1]
		UI.text_shadow(ci, Vector2(0, y), String(l[0]), sz, Color(l[2], la), "caps", HORIZONTAL_ALIGNMENT_CENTER, size.x,
			Color(OUTLINE, 0.9))
		y += 12.0
	if kind == "lead" and c >= SWAP_AT and t < board_at():
		var lt := "%s TAKES THE LEAD!" % team if team != "" else "TAKES THE LEAD!"
		if UI.text_width(lt, 8, "caps") > size.x * 0.7:
			lt = "TAKES THE LEAD!"
		var tw := UI.text_width(lt, 8, "caps") + 14.0
		var lp := clampf((c - SWAP_AT) / 0.08, 0.0, 1.0)
		var r := Rect2(roundf((size.x - tw * lp) / 2.0), strip.end.y + 3.0, roundf(tw * lp), 13)
		ci.draw_rect(r, Color(YELLOW, a))
		ci.draw_rect(r, Color(OUTLINE, a), false, 1.0)
		if lp >= 1.0:
			UI.text(ci, Vector2(r.position.x, r.position.y + 10), lt, 8, Color(OUTLINE, a), "caps", HORIZONTAL_ALIGNMENT_CENTER, tw)
	if t < board_at():
		UI.text(ci, Vector2(0, size.y - 4), "TAP TO SKIP", 8, Color(UI.TEXT, 0.5 * la), "caps", HORIZONTAL_ALIGNMENT_CENTER, size.x)

## Where a note under the show goes (the dive note: TOO EARLY / TOO LATE), px from the top.
func note_y() -> float:
	return maxf(top, TEXT_TOP) + block_h() + 4.0

## The block's height: the word, the scorer's lines, the TAKES THE LEAD! pill under it.
func block_h() -> float:
	var cap := roundf(word_base() * 0.55)
	var n := _lines().size()
	return cap + 16.0 + (10.0 + 12.0 * n if n > 0 else 0.0) + (16.0 if kind == "lead" else 0.0)

## Where the block goes, px from the top: under the scoreboard, unless the scorer's up there,
## then down at the bottom of the screen, clear of him (and of TAP TO SKIP).
func place(size: Vector2, v: PoolView) -> float:
	if v == null or hero == null:
		return TEXT_TOP
	var hy := v.to_screen(hero.pos).y
	var body := Vector2(hy - 22.0, hy + 6.0)   # his head and raised fist to the splash under him
	if body.y < TEXT_TOP or body.x > TEXT_TOP + block_h():
		return TEXT_TOP
	return roundf(size.y - block_h() - 14.0)

func word_base() -> int:
	return (WORD_BIG if big() else WORD) + word_add

## The widest thing on the strip, px.
func content_w(w: float) -> float:
	var base := word_base()
	var most := 0.0
	for word in ["GOAL!", headline_swap()]:
		if word != "":
			most = maxf(most, UI.text_width(word, word_size(word, base, 1.0, w), "big"))
	for l: Array in _lines():
		most = maxf(most, UI.text_width(String(l[0]), int(l[1]), "caps"))
	return most

## The word that takes over from GOAL!, or "".
func headline_swap() -> String:
	return {"tie": "TIE GAME!", "winner": "GAME WINNER!"}.get(kind, "")

## The scorer's lines: [[text, size, colour]]: "#7 JACKSON MILLER", "3RD GOAL TODAY". None
## without a scorer: nothing's made up.
func _lines() -> Array:
	if scorer == null:
		return []
	var name := ("#%d %s %s" % [scorer.number, scorer.first, scorer.last]).strip_edges().to_upper()
	var out := [[name, 16 if UI.text_width(name, 16, "caps") <= 300.0 else 8, UI.TEXT]]
	if goals_today > 0:
		out.append(["%s GOAL TODAY" % ordinal(goals_today), 8, YELLOW])
	return out

static func ordinal(n: int) -> String:
	var suf := "TH"
	if n % 100 < 11 or n % 100 > 13:
		suf = {1: "ST", 2: "ND", 3: "RD"}.get(n % 10, "TH")
	return "%d%s" % [n, suf]

## The word's scale `u` seconds after it comes in: from small, past full size, back a touch
## under, settled by about 0.35 s.
static func punch(u: float) -> float:
	if u < 0.1:
		return lerpf(0.4, 1.28, 1.0 - pow(1.0 - u / 0.1, 2.0))
	if u < 0.22:
		return lerpf(1.28, 0.94, (u - 0.1) / 0.12)
	if u < 0.34:
		return lerpf(0.94, 1.0, (u - 0.22) / 0.12)
	return 1.0

## The word's font size at `base` and scale `pop`, never wider than the screen (its outline
## and all), however narrow, even at the top of the punch.
static func word_size(word: String, base: int, pop: float, w: float) -> int:
	var most := base * (w - 8.0) / maxf(1.0, UI.text_width(word, base, "big"))
	return int(floorf(minf(base * pop, most)))

## A big word centred on `cy`, in a thick dark-blue pixel outline with a drop shadow.
static func _outlined(ci: CanvasItem, size: Vector2, text: String, s: int, cy: float, col: Color) -> void:
	var y := roundf(cy + s * 0.55 * 0.5)
	var dark := Color(OUTLINE, col.a)
	for d in [Vector2(0, 4), Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2),
			Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
		UI.text(ci, Vector2(0, y) + d, text, s, dark, "big", HORIZONTAL_ALIGNMENT_CENTER, size.x)
	UI.text(ci, Vector2(0, y), text, s, col, "big", HORIZONTAL_ALIGNMENT_CENTER, size.x)

func _bodies() -> Array[Swimmer]:
	var out: Array[Swimmer] = []
	out.append_array(mates)
	for s in [hero, keeper]:
		if s != null:
			out.append(s)
	return out
