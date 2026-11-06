class_name EventBanner
extends RefCounted
## Every gameplay callout, one at a time, all in one style: BAR-DOWN!'s lettering and animation
## just under the scoreboard (Hud.callout): bursting in, held for about a second, shrinking away. The named events (GOAL!, PENALTY!, EXCLUSION!, BLOCK!, SAVE!, STEAL!, TURNOVER!, FOUL!,
## TIMEOUT!) have their own word, colour and priority; anything else ("WIDE!", "DRIVE LEFT!")
## goes through show() at the bottom of the order.
##
## A callout never interrupts a bigger one still on screen. A named event that arrives while a
## bigger one is up waits its turn behind it (the biggest one waiting wins); a plain one is
## dropped, since by then it's stale. Drawing only: it never touches input or the play.

const YELLOW := Color("ffd83d")
const CYAN := Color("45dfff")
const RED := Color("ff4545")
const WHITE := Color("ffffff")
const DUR := 1.0               # seconds on screen: pop in, hold, shrink away (the last BarHit.OUT)

const EVENTS := {
	"goal": {"text": "GOAL!", "col": YELLOW, "prio": 6},
	"penalty": {"text": "PENALTY!", "col": RED, "prio": 5},
	"exclusion": {"text": "EXCLUSION!", "col": RED, "prio": 4},
	"block": {"text": "BLOCK!", "col": YELLOW, "prio": 3},
	"save": {"text": "SAVE!", "col": CYAN, "prio": 3},
	"steal": {"text": "STEAL!", "col": CYAN, "prio": 2},
	"turnover": {"text": "TURNOVER!", "col": WHITE, "prio": 1},
	"foul": {"text": "FOUL!", "col": WHITE, "prio": 1},
	"timeout": {"text": "TIMEOUT!", "col": YELLOW, "prio": 1},
}

var cur := {}                  # {text, col, t, prio, kind}
var queued := {}

## A named event: one of EVENTS' keys.
func event(kind: String) -> void:
	var ev: Dictionary = EVENTS[kind]
	_offer({"text": ev.text, "col": ev.col, "t": 0.0, "prio": int(ev.prio), "kind": kind,
		"dur": float(ev.get("dur", DUR))})

## Any other callout ("WIDE!", "COUNTERATTACK!"), below every named event.
func show(text: String, col: Color = WHITE) -> void:
	_offer({"text": text, "col": col, "t": 0.0, "prio": 0, "kind": ""})

func clear() -> void:
	cur = {}
	queued = {}

func is_empty() -> bool:
	return cur.is_empty()

## The named event on screen ("goal", "block"...), or "" (a plain callout, or none).
func kind() -> String:
	return String(cur.get("kind", ""))

func text() -> String:
	return String(cur.get("text", ""))

func step(dt: float) -> void:
	if cur.is_empty():
		return
	cur.t += dt
	if float(cur.t) >= float(cur.get("dur", DUR)):
		cur = queued
		queued = {}

func draw(ci: CanvasItem, size: Vector2) -> void:
	if cur.is_empty():
		return
	Hud.callout(ci, size, cur.text, cur.col, cur.t, float(cur.get("dur", DUR)) - float(cur.t))

func _offer(b: Dictionary) -> void:
	if cur.is_empty() or int(b.prio) >= int(cur.prio):
		if not cur.is_empty() and int(cur.prio) > 0 and cur.text == b.text:
			return   # the same callout again while it's up: no repeat
		cur = b
		queued = {}
	elif int(b.prio) > 0 and (queued.is_empty() or int(b.prio) >= int(queued.prio)):
		queued = b
