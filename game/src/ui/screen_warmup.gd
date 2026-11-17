extends Node
## SCREEN WARM-UP: compiles every screen's script (and everything it pulls in) before you first
## open it, so Game.goto never stalls on it. Opening a screen for the first time used to freeze
## the game for 150-800 ms while GDScript compiled it; once compiled it opens in ~15 ms.
##
## With threads (desktop, mobile): one screen at a time on a loader thread, the game running on.
## Without (the web build): one screen on the main thread every few frames, only while nothing
## is going on (no screen change under way, no button held), most likely screens first.
## Game.goto's own load() of a screen still being compiled just waits for it to finish.

## The screens you're likeliest to open next, in order; every other screen follows.
const FIRST := ["careers", "new_career", "hub", "more", "roster", "player", "matchup", "match",
	"game_summary", "player_development", "recap", "schedule", "recruiting", "training", "conference",
	"top20", "news", "program", "coaching", "facilities", "records", "awards", "trophy_room",
	"store", "visual_shop", "settings", "quick_match", "howto", "drill", "multiplayer", "mp_match"]
const MAIN_THREAD_GAP := 4   # (no threads) frames between two compiles

var _queue: Array[String] = []
var _busy := ""              # the path on the loader thread now
var _keep: Array = []        # every warmed script, held so the cache never drops it
var _threaded := true
var _wait := 0
var _last_input := 0         # (no threads) when you last touched anything, Time.get_ticks_msec
const IDLE_MS := 300         # (no threads) ...and how long ago that has to be for a compile

## Can work go on a thread here? Everywhere but the web build without thread support.
static func threads_ok() -> bool:
	return OS.has_feature("threads") or not OS.has_feature("web")

func start() -> void:
	_threaded = threads_ok()
	var seen := {}
	for s in FIRST:
		_add(Game.SCREEN_PATHS.get(s, "res://src/ui/screens/%s.gd" % s), seen)
	for f in ResourceLoader.list_directory("res://src/ui/screens/"):
		var name := String(f).trim_suffix(".remap").trim_suffix(".gdc").trim_suffix(".gd")
		# (the developer labs only open in Developer Mode)
		if name.ends_with("_lab") or name.begins_with("dev_") or name.ends_with("/"):
			continue
		_add("res://src/ui/screens/%s.gd" % name, seen)
	for p in Game.SCREEN_PATHS.values():
		_add(p, seen)
	set_process(true)

func _add(path: String, seen: Dictionary) -> void:
	if seen.has(path) or not ResourceLoader.exists(path):
		return
	seen[path] = true
	_queue.append(path)

## Done (or nothing to do)?
func finished() -> bool:
	return _queue.is_empty() and _busy == ""

func _ready() -> void:
	set_process(false)

func _exit_tree() -> void:
	_keep.clear()   # (quitting: let the scripts go before the engine shuts down)

func _input(_event: InputEvent) -> void:
	_last_input = Time.get_ticks_msec()

func _process(_delta: float) -> void:
	if _busy != "":
		var st := ResourceLoader.load_threaded_get_status(_busy)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_keep.append(ResourceLoader.load_threaded_get(_busy))
		_busy = ""
	if _queue.is_empty():
		set_process(false)
		return
	if _threaded:
		var path: String = _queue.pop_front()
		if ResourceLoader.has_cached(path):
			_keep.append(load(path))
		elif ResourceLoader.load_threaded_request(path) == OK:
			_busy = path
		return
	# no threads: a compile freezes this frame, so only when it can't be felt
	if _wait > 0:
		_wait -= 1
		return
	if Game.is_changing_screen() or Time.get_ticks_msec() - _last_input < IDLE_MS:
		return
	_keep.append(load(_queue.pop_front()))
	_wait = MAIN_THREAD_GAP
