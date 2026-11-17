class_name BroadcastFx
extends RefCounted
## THE BROADCAST PRESENTATION UPGRADES (the Premium Visual Upgrades update): TV graphics at the
## stoppages of a game you play. Level 1 is the existing scoreboard, clocks and names, everybody's;
## nothing a player needs is ever moved behind a level.
##   Level 2 GAMEDAY BROADCAST   a scoring strip with the team's logo bouncing in; a light across the board
##   Level 3 ENHANCED BROADCAST  lower-thirds: the scorer's portrait and his real line, keeper saves;
##                               the team comparison at the breaks
## Every number is the match's own (MatchState). Graphics only draw at stoppages: `live` hides
## them the moment play is on, so they never sit over the shooting stick or the keeper's taps.

const HOLD := 2.3
const NAVY := Color("0b1d5c")

var level := 1
var calm := false
var msg := {}                  # the graphic up now: {kind, t, ...}

func _init(lv: int = 1, p_calm: bool = false) -> void:
	level = clampi(lv, 1, VisualUpgrades.top("broadcast"))
	calm = p_calm

## A player's real line: "5 GOALS | 7 SHOTS | 71% SHOOTING".
static func stat_line(goals: int, shots: int) -> String:
	var sh := maxi(shots, goals)
	return "%d GOAL%s | %d SHOT%s | %d%% SHOOTING" % [goals, "" if goals == 1 else "S", sh, "" if sh == 1 else "S", roundi(100.0 * goals / maxf(1.0, sh))]

func goal(who: PoloPlayer, team: PoloTeam, goals: int, shots: int, score: String) -> void:
	if level < 2:
		return
	msg = {"kind": "goal", "t": 0.0, "who": who, "team": team, "goals": goals, "shots": shots, "score": score}

func save(keeper: PoloPlayer, team: PoloTeam, saves: int) -> void:
	if level < 3 or keeper == null:
		return
	msg = {"kind": "save", "t": 0.0, "who": keeper, "team": team, "saves": saves}

func step(dt: float) -> void:
	if not msg.is_empty():
		msg.t = float(msg.t) + dt
		if float(msg.t) > HOLD:
			msg = {}

## `live`: the ball's in play (nothing but the tag draws). The lower third sits at the bottom,
## clear of the goal show's words (always under the scoreboard: GoalShow.place).
func draw(ci: CanvasItem, size: Vector2, live: bool, st: MatchState) -> void:
	if msg.is_empty() or live:
		return
	var u := 1.0 if calm else clampf(float(msg.t) / 0.18, 0.0, 1.0)
	var out := 0.0 if calm else clampf((float(msg.t) - HOLD + 0.2) / 0.2, 0.0, 1.0)
	var h := 34.0 if level >= 3 else 20.0
	var y := size.y - h - 18.0
	var w := minf(size.x - 16.0, 300.0 if level >= 3 else 210.0)
	var x := roundf(lerpf(-w, 8.0, u * (1.0 - out)))
	var tm: PoloTeam = msg.team
	Deck.frame(ci, Rect2(x, y, w, h), NAVY, Color.WHITE)
	ci.draw_rect(Rect2(x + 1, y + 1, 5, h - 2), tm.c1)
	ci.draw_rect(Rect2(x + 6, y + 1, 2, h - 2), tm.c2)
	var who: PoloPlayer = msg.who
	if level == 2:
		var hop := 0.0 if calm else roundf(absf(sin(float(msg.t) * 6.0)) * 2.0)
		TeamLogo.draw_in(ci, Rect2(x + 10, y + 2 - hop, 22, 16), tm)
		Deck.text(ci, x + 36, y + 10, "GOAL  %s" % _short(who), 8, Color.WHITE)
		Deck.rtext(ci, x + w - 6, y + 10, String(msg.score), 8, UI.GOLD)
		return
	var port := Vector2i(30, 32)
	Portrait.draw_zoomed(ci, Vector2(x + 12 + port.x * 0.5, y + 1), who, tm, port)
	var tx := x + 16 + port.x
	Deck.text(ci, tx, y + 9, "#%d  %s %s" % [who.number, who.first.to_upper(), who.last.to_upper()], 8, Color.WHITE)
	if String(msg.kind) == "save":
		Deck.text(ci, tx, y + 21, "%d SAVE%s TODAY" % [int(msg.saves), "" if int(msg.saves) == 1 else "S"], 8, UI.ACCENT)
	else:
		Deck.text(ci, tx, y + 21, stat_line(int(msg.goals), int(msg.shots)), 8, UI.ACCENT)
	TeamLogo.draw_in(ci, Rect2(x + w - 30, y + 3, 26, 18), tm)

static func _short(p: PoloPlayer) -> String:
	return "#%d %s" % [p.number, p.short_name().to_upper()] if p != null else ""

## The team comparison at a break (Level 3 up), real numbers, above the score card.
func comparison(ci: CanvasItem, size: Vector2, card: Rect2, st: MatchState) -> void:
	if level < 3:
		return
	var rows := [["SHOTS", st.shots], ["SAVES", st.saves], ["STEALS", st.steals]]
	var w := card.size.x
	var y := maxf(28.0, card.position.y - 16.0)
	Deck.frame(ci, Rect2(card.position.x, y, w, 13), NAVY, Color.WHITE)
	var cw := w / rows.size()
	for i in rows.size():
		var a: Array = rows[i][1]
		Deck.ctext(ci, Rect2(card.position.x + i * cw, y + 2, cw, 10), "%s %d-%d" % [rows[i][0], int(a[0]), int(a[1])], 8, UI.ACCENT)

## Level 2 up: a band of light across the scoreboard as the score changes.
func board_sweep(ci: CanvasItem, board: Rect2, show: GoalShow) -> void:
	if level < 2 or calm or not show.active() or show.t < show.board_at():
		return
	var u := clampf((show.t - show.board_at()) / 0.35, 0.0, 1.0)
	if u >= 1.0:
		return
	ci.draw_rect(Rect2(board.position.x + board.size.x * u - 6, board.position.y, 6, board.size.y), Color(1, 1, 1, 0.45))
