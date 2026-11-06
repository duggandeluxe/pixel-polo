extends Node
## Sfx: global audio autoload (shared with Retro Swim).
##
## Plays the procedurally generated chiptune assets in res://assets/audio/
## (regenerate them with `python3 tools/gen_audio.py`, then re-import the project).
##
##   Sfx.play("splash")               # one-shot SFX; unknown names are silently ignored
##   Sfx.play("perfect", 1.1, -4.0)   # custom pitch scale and volume offset (dB)
##   Sfx.music("race")                # crossfade to menu/race/victory/anthem/dream; "" stops
##   Sfx.crowd(0.6)                   # crowd ambience target level 0..1 (smoothed); 0 = off
##
## Keeps playing while the tree is paused and is safe with the Dummy audio driver
## (headless / CI). Players use the "SFX" / "Music" buses when the project defines
## them, otherwise "Master". The crowd bed counts as SFX (it follows sfx_on).
##
## Audio must never silently drop out: a watchdog restarts a looping music track that
## should be playing but isn't (after an iOS audio interruption, a route change such
## as AirPods switching, or the app coming back from the background), resuming where
## it was. The iOS audio session itself is set in project.godot (Playback + mix with
## others) so the Ring/Silent switch and AirPods auto-switching don't mute the game.

const AUDIO_DIR := "res://assets/audio/"
const POOL_SIZE := 12

## Every one-shot sound; the file is AUDIO_DIR + name + ".wav".
const SFX_NAMES := [
	# UI
	"click", "back", "confirm", "error", "card", "coins", "levelup", "commit", "injury", "whistle",
	# race
	"beep_marks", "beep_start", "dive", "splash", "stroke", "perfect", "good", "miss", "breath",
	"turn", "touch", "dq", "cheer", "record", "pb", "gear_up", "gear_down", "countdown", "gasp",
	"lap", "bell",
	# the goal show (GoalShow)
	"goal", "score_tick",
	# in off the frame (BarHit)
	"clang", "bang",
]
## Track name -> file name (without .wav).
const MUSIC_FILES := {
	"menu": "music_menu",
	"race": "music_race",
	"victory": "music_victory",
	"anthem": "music_anthem",
	"dream": "music_dream",
}
## Tracks that loop seamlessly; the others (victory, anthem) play once.
const LOOPED_TRACKS := ["menu", "race", "dream"]
const CROWD_FILE := "crowd"
## Repetitive sounds that get a random +-PITCH_JITTER pitch variation on every play.
const JITTER_SOUNDS := ["stroke", "splash", "click", "breath", "turn"]
const PITCH_JITTER := 0.03
## The same sound started again within this many ms is dropped (stops +6 dB stacking
## when several swimmers trigger it on the same frame).
const DEDUPE_MSEC := 25
## Output trims in dB (the relative levels are already baked into the files).
const MUSIC_DB := 0.0
const CROWD_DB := 0.0
## How fast the crowd level follows crowd() (1/s; roughly 1 s to settle).
const CROWD_SMOOTHING := 2.5
## Linear gain treated as silence (-60 dB).
const SILENT := 0.001
## How often (s) the watchdog checks that the music that should be playing is playing.
const WATCHDOG_EVERY := 0.5

var sfx_on := true: set = set_sfx_on
var music_on := true: set = set_music_on

var _ready_done := false
var _streams: Dictionary = {}          # sound name -> AudioStream
var _music_streams: Dictionary = {}    # track name -> AudioStream or null (lazy cache)
var _last_start: Dictionary = {}       # sound name -> Time.get_ticks_msec() of last start
var _pool: Array[AudioStreamPlayer] = []
var _pool_cursor := 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_gain: Array[float] = [0.0, 0.0]     # 0..1 fade position per music player
var _music_target: Array[float] = [0.0, 0.0]
var _music_speed: Array[float] = [0.0, 0.0]    # gain units per second
var _music_active := 0
var _music_name := ""
var _crowd_player: AudioStreamPlayer
var _crowd_target := 0.0
var _crowd_level := 0.0
var _rng := RandomNumberGenerator.new()
var _watchdog_t := 0.0
var _music_pos: Array[float] = [0.0, 0.0]      # last known playback position per music player


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_rng.randomize()
	var sfx_bus := _bus_or_master(&"SFX")
	var music_bus := _bus_or_master(&"Music")
	for i in POOL_SIZE:
		_pool.append(_make_player("Sfx%d" % i, sfx_bus))
	for i in 2:
		_music_players.append(_make_player("Music%d" % i, music_bus))
	_crowd_player = _make_player("Crowd", sfx_bus)
	for sound_name: String in SFX_NAMES:
		var stream := _load_stream(sound_name)
		if stream != null:
			_streams[sound_name] = stream
	var crowd_stream := _load_stream(CROWD_FILE)
	if crowd_stream != null:
		_set_looping(crowd_stream)
		_crowd_player.stream = crowd_stream
	_ready_done = true
	# An earlier autoload may have asked for music before we were ready.
	if _music_name != "" and music_on:
		_start_music(_music_name, 0.0)


func _process(delta: float) -> void:
	if not _ready_done:
		return
	for i in 2:
		if _music_gain[i] != _music_target[i]:
			_music_gain[i] = move_toward(_music_gain[i], _music_target[i], _music_speed[i] * delta)
			_apply_music_volume(i)
			if _music_gain[i] <= 0.0 and _music_target[i] <= 0.0:
				_music_players[i].stop()
	_update_crowd(delta)
	_watchdog_t -= delta
	if _watchdog_t <= 0.0:
		_watchdog_t = WATCHDOG_EVERY
		_music_watchdog()


func _notification(what: int) -> void:
	# Coming back from a phone call, Siri, Control Center, the app switcher or an audio
	# route change: make sure the music and the crowd bed are running again.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		if _ready_done:
			_watchdog_t = 0.25


# --------------------------------------------------------------------------- public API

## Plays a one-shot sound effect by name (see SFX_NAMES). [param pitch] scales the
## playback speed, [param vol_db] is added to the sound's volume. Unknown names, or
## sounds whose file is missing, are silently ignored.
func play(sound_name: String, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if not sfx_on or not _ready_done or not is_inside_tree():
		return
	var stream: AudioStream = _streams.get(sound_name)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	var last_start: int = _last_start.get(sound_name, -DEDUPE_MSEC)
	if now - last_start < DEDUPE_MSEC:
		return
	_last_start[sound_name] = now
	if sound_name in JITTER_SOUNDS:
		pitch *= _rng.randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)
	var p := _next_player()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.05, 8.0)
	p.volume_db = vol_db
	p.play()


## Crossfades to a music track: "menu", "race", "victory", "anthem" or "dream";
## "" fades the music out (calling it again with a shorter fade speeds that up).
## Asking for the track that is already playing does nothing. "victory" and
## "anthem" play once; the others loop seamlessly.
func music(track_name: String, fade: float = 0.6) -> void:
	if track_name != "" and track_name == _music_name and (not music_on or _is_music_playing()):
		return
	_music_name = track_name
	if not _ready_done:
		return
	if track_name == "" or not music_on:
		_fade_all_music_out(fade)
		return
	_start_music(track_name, fade)


## Sets the crowd ambience target level, 0..1. The actual level glides there over
## about a second; at 0 the crowd fades out and the player stops.
func crowd(level: float) -> void:
	_crowd_target = clampf(level, 0.0, 1.0)


## Enables or disables sound effects (including the crowd bed). Disabling stops
## everything that is currently playing; the crowd resumes on re-enable.
func set_sfx_on(v: bool) -> void:
	sfx_on = v
	if not v and _ready_done:
		for p in _pool:
			p.stop()
		_crowd_player.stop()


## Enables or disables music. Disabling stops it at once; re-enabling restarts the
## current track if it is a looping one (the one-shot jingles are not replayed).
func set_music_on(v: bool) -> void:
	if v == music_on:
		return
	music_on = v
	if not _ready_done:
		return
	if not v:
		_fade_all_music_out(0.0)
	elif _music_name in LOOPED_TRACKS:
		_start_music(_music_name, 0.3)


## Stops every sound effect, the music and the crowd immediately.
func stop_all() -> void:
	_music_name = ""
	_crowd_target = 0.0
	_crowd_level = 0.0
	if not _ready_done:
		return
	for p in _pool:
		p.stop()
	_fade_all_music_out(0.0)
	_crowd_player.stop()


# --------------------------------------------------------------------------- internals

func _make_player(node_name: String, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.bus = bus
	add_child(p)
	return p


func _bus_or_master(bus_name: StringName) -> StringName:
	return bus_name if AudioServer.get_bus_index(bus_name) >= 0 else &"Master"


func _load_stream(file_base: String) -> AudioStream:
	var path := AUDIO_DIR + file_base + ".wav"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


## Makes an imported WAV loop over its whole length. The files are rendered so
## that the end flows straight into the start.
func _set_looping(stream: AudioStream) -> void:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return
	var frames := _frame_count(wav)
	if frames <= 0:
		return
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames


func _frame_count(wav: AudioStreamWAV) -> int:
	var channels := 2 if wav.stereo else 1
	match wav.format:
		AudioStreamWAV.FORMAT_16_BITS:
			return floori(wav.data.size() / (2.0 * channels))
		AudioStreamWAV.FORMAT_8_BITS:
			return floori(wav.data.size() / float(channels))
		_:
			# Compressed import (IMA-ADPCM / QOA): derive the frame count from the length.
			return roundi(wav.get_length() * wav.mix_rate)


func _next_player() -> AudioStreamPlayer:
	for i in POOL_SIZE:
		var idx := (_pool_cursor + i) % POOL_SIZE
		if not _pool[idx].playing:
			_pool_cursor = (idx + 1) % POOL_SIZE
			return _pool[idx]
	# Every voice is busy: steal the next one in round-robin order (the oldest).
	var p := _pool[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % POOL_SIZE
	p.stop()
	return p


func _get_music_stream(track_name: String) -> AudioStream:
	if _music_streams.has(track_name):
		return _music_streams[track_name]
	var stream: AudioStream = null
	if MUSIC_FILES.has(track_name):
		var file_base: String = MUSIC_FILES[track_name]
		stream = _load_stream(file_base)
		if stream != null and track_name in LOOPED_TRACKS:
			_set_looping(stream)
	_music_streams[track_name] = stream
	return stream


func _is_music_playing() -> bool:
	return _music_players[_music_active].playing and _music_target[_music_active] > 0.0


func _start_music(track_name: String, fade: float) -> void:
	var stream := _get_music_stream(track_name)
	if stream == null:
		_fade_all_music_out(fade)
		return
	var other := 1 - _music_active
	# Switching back to the track that is still fading out: just fade it back in.
	var back := _music_players[other]
	if back.playing and back.stream == stream and _music_target[other] <= 0.0:
		_fade_music(_music_active, 0.0, fade)
		_fade_music(other, 1.0, fade)
		_music_active = other
		return
	# The quieter player takes the new track; the other one fades out.
	var incoming := other if _music_gain[other] <= _music_gain[_music_active] else _music_active
	_fade_music(1 - incoming, 0.0, fade)
	var p := _music_players[incoming]
	p.stop()
	p.stream = stream
	_music_pos[incoming] = 0.0
	_music_gain[incoming] = 0.0
	_fade_music(incoming, 1.0, fade)
	p.play()
	_music_active = incoming


func _fade_music(i: int, target: float, fade: float) -> void:
	_music_target[i] = target
	if fade <= 0.0:
		_music_gain[i] = target
		_music_speed[i] = 0.0
	else:
		_music_speed[i] = 1.0 / fade
	_apply_music_volume(i)
	if _music_gain[i] <= 0.0 and target <= 0.0:
		_music_players[i].stop()


func _fade_all_music_out(fade: float) -> void:
	for i in 2:
		_fade_music(i, 0.0, fade)


func _apply_music_volume(i: int) -> void:
	# Equal-power curve so a crossfade does not dip in the middle.
	var amp := sin(clampf(_music_gain[i], 0.0, 1.0) * PI * 0.5)
	_music_players[i].volume_db = linear_to_db(maxf(amp, SILENT * 0.1)) + MUSIC_DB


## Restarts the active looping track if it should be audible but its player stopped.
func _music_watchdog() -> void:
	for i in 2:
		var p := _music_players[i]
		if p.playing:
			_music_pos[i] = p.get_playback_position()
	if not music_on or _music_name == "" or not _music_name in LOOPED_TRACKS:
		return
	var i := _music_active
	var p := _music_players[i]
	if _music_target[i] <= 0.0 or p.playing or p.stream == null:
		return
	var at := _music_pos[i]
	if at >= p.stream.get_length() - 0.05:
		at = 0.0
	p.play(at)
	_apply_music_volume(i)


func _update_crowd(delta: float) -> void:
	_crowd_level = lerpf(_crowd_level, _crowd_target, 1.0 - exp(-CROWD_SMOOTHING * delta))
	if absf(_crowd_level - _crowd_target) < 0.002:
		_crowd_level = _crowd_target
	if sfx_on and _crowd_level > SILENT and _crowd_player.stream != null:
		_crowd_player.volume_db = linear_to_db(_crowd_level) + CROWD_DB
		if not _crowd_player.playing:
			# Start at a random point so the loop does not always begin the same way.
			_crowd_player.play(_rng.randf() * _crowd_player.stream.get_length())
	elif _crowd_player.playing:
		_crowd_player.stop()
