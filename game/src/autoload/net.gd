extends Node
## Multiplayer session: finding rooms, the lobby, clock sync, and carrying match messages.
## Three links share one star topology (host = peer 1): Bluetooth, Wi-Fi/hotspot, and Online
## (a relay server, room codes). Ported from Retro Swim; the match itself is MpMatch.

signal rooms_changed
signal lobby_changed
signal joined
signal join_failed(reason: String)
signal ended(reason: String)             # the session is over for us (host left, link lost)
signal room_code_ready(code: String)     # online host: the code to share

const SNAP_MS := 83                      # ~12 frames a second while you attack
const SILENCE_MS := 9000                 # nothing heard for this long: the other phone is gone
                                         # (both sides send something every 2 s, even when idle)

var ble: BleTransport
var lan: LanTransport
var online: RelayTransport
var t: NetTransport = null
var role := ""                           # "" | "host" | "client" (client before welcome: my_id == 0)
var my_id := 0
var room_name := ""
var players := {}                        # player id -> {"id", "name", "club", "wins"}
var order: Array = []                    # host first
var cfg := {"minutes": MatchState.QUARTER_MIN, "equal": true}
var rooms := {}                          # key -> room (from scanning)
var playing := false
var match_n := 0
var game: MpMatch = null                 # the match being played
var offset_ms := 0.0                     # host clock - local clock
var match_params := {}                   # tests: extra match screen params (autoplay)

var _samples: Array = []
var _next_ping := 0
var _next_frame := 0
var _frame := PackedByteArray()          # my latest attack frame, sent at SNAP_MS
var _last_rx := 0                        # when we last heard from the other phone (ms)
var _pid := {}                           # host: transport id -> player id
var _tid := {}                           # host: player id -> transport id

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ble = BleTransport.new()
	lan = LanTransport.new()
	online = RelayTransport.new(NetConfig.relay_url())
	for tr in [ble, lan, online]:
		tr.room_found.connect(_on_room.bind(tr))
		tr.connected.connect(_on_connected.bind(tr))
		tr.connect_failed.connect(_on_connect_failed.bind(tr))
		tr.peer_joined.connect(_on_peer_joined.bind(tr))
		tr.peer_left.connect(_on_peer_left.bind(tr))
		tr.lost_host.connect(_on_lost_host.bind(tr))
		tr.host_failed.connect(_on_host_failed.bind(tr))
		tr.packet.connect(_on_packet.bind(tr))
	online.room_ready.connect(func(code): room_code_ready.emit(code))
	online.became_host.connect(_on_became_host)

## A cap design id from the other phone, or classic if this version doesn't know it.
static func _known_cap(id: String) -> String:
	return id if Caps.design(id).id == id else Caps.DEFAULT

## Wi-Fi needs real sockets (ENet, UDP beacons): a browser build has neither, so it's hidden.
func has_lan() -> bool:
	return not OS.has_feature("web")

## Bluetooth needs the native plugin (Android today). Elsewhere the option is hidden.
func has_bluetooth() -> bool:
	return ble.ble != null or OS.has_feature("android")

func has_online() -> bool:
	return online.status() == "ready"

func transport(kind: String) -> NetTransport:
	match kind:
		"ble":
			return ble
		"online":
			return online
	return lan

func active() -> bool:
	return role != ""

func is_host() -> bool:
	return role == "host"

func now_ms() -> float:
	return Time.get_ticks_usec() / 1000.0 + (offset_ms if role == "client" else 0.0)

func my_name() -> String:
	var n: String = Game.settings.get("mp_name", "")
	if n == "" and Game.career != null:
		n = Game.career.coach.get("last", "")
	return Proto.clean_name(n)

func my_club() -> int:
	return int(Game.settings.get("mp_club", 3)) % League.club_count()

func room_code() -> String:
	return online.code if t == online else ""

# ================================================================== host
func host(kind: String) -> Error:
	leave()
	t = transport(kind)
	room_name = my_name()
	var err := t.host(room_name, 2)
	if err != OK:
		t = null
		return err
	_become_host()
	return OK

func _become_host() -> void:
	role = "host"
	my_id = 1
	players = {1: {"id": 1, "name": room_name, "club": my_club(), "wins": 0, "cap": Caps.selected()}}
	order = [1]
	match_n = 0
	lobby_changed.emit()

func set_cfg(key: String, value) -> void:
	if not is_host() or playing:
		return
	cfg[key] = value
	_broadcast_lobby()

## Either player picks their own club.
func set_club(i: int) -> void:
	Game.settings.mp_club = i
	Game.save_settings()
	if is_host():
		players[1].club = i
		_broadcast_lobby()
	elif my_id != 0:
		t.send(NetTransport.HOST_ID, Proto.pack({"t": "club", "i": i}))

func can_start() -> bool:
	return is_host() and not playing and order.size() == 2

func start_match() -> void:
	if not can_start():
		return
	match_n += 1
	var msg := {"t": "match", "n": match_n, "seed": randi(), "minutes": float(cfg.minutes), "equal": bool(cfg.equal),
		"clubs": [int(players[order[0]].club), int(players[order[1]].club)],
		"names": [players[order[0]].name, players[order[1]].name],
		"designs": [String(players[order[0]].get("cap", "classic")), String(players[order[1]].get("cap", "classic"))]}
	_broadcast(msg)
	_begin_match(msg)
	game.host_start()

func _add_player(tid: int, name: String) -> void:
	var pid := 2
	_pid[tid] = pid
	_tid[pid] = tid
	var nm := Proto.clean_name(name)
	if nm == players[1].name:
		nm = nm.substr(0, Proto.NAME_MAX - 2) + " 2"
	players[pid] = {"id": pid, "name": nm, "club": (players[1].club + 1) % League.club_count(), "wins": 0, "cap": "classic"}
	order.append(pid)
	_send_to(pid, {"t": "welcome", "id": pid, "room": room_name})
	_broadcast_lobby()

func _drop_player(pid: int) -> void:
	if not players.has(pid):
		return
	players.erase(pid)
	order.erase(pid)
	var tid: int = _tid.get(pid, 0)
	_tid.erase(pid)
	_pid.erase(tid)
	if playing and game != null:
		game.host_forfeit(1)
	_broadcast_lobby()

func _broadcast_lobby() -> void:
	if not is_host():
		return
	var list := []
	for id in order:
		list.append(players[id])
	_broadcast({"t": "lobby", "players": list, "cfg": cfg, "room": room_name, "playing": playing})
	t.set_room_info(order.size())
	lobby_changed.emit()

func _broadcast(msg: Dictionary) -> void:
	var data := Proto.pack(msg)
	for pid in _tid:
		t.send(_tid[pid], data)

func _send_to(pid: int, msg: Dictionary) -> void:
	if _tid.has(pid):
		t.send(_tid[pid], Proto.pack(msg))

# ================================================================== client
func scan(kind: String) -> void:
	if role != "":
		leave()
	if t and t != transport(kind):
		t.scan_stop()
	t = transport(kind)
	rooms.clear()
	t.scan_start()
	rooms_changed.emit()

func stop_scan() -> void:
	if t:
		t.scan_stop()
	if role == "":
		t = null

## room: a scanned room, {"addr", "port"} for Wi-Fi, {"code"} or {"quick": true} online.
func join(room: Dictionary, kind: String = "") -> Error:
	if kind != "":
		t = transport(kind)
	elif t == null:
		t = lan if room.has("port") else ble
	t.scan_stop()
	var r := room.duplicate()
	r["name"] = my_name()
	var err := t.join(r)
	if err != OK:
		return err
	role = "client"
	my_id = 0
	room_name = String(room.get("name", room.get("code", "")))
	return OK

# ================================================================== the match
func _begin_match(msg: Dictionary) -> void:
	playing = true
	_frame = PackedByteArray()
	game = MpMatch.new(self, msg, 0 if is_host() else 1)
	var params := {"mp": true}
	params.merge(match_params)
	Game.goto("mp_match", params)

## Host: an official state for the guest (MpMatch calls this).
func send_match(msg: Dictionary) -> void:
	if is_host():
		_broadcast(msg)

## Either phone: a message for the other phone about the match.
func send_game(msg: Dictionary, reliable: bool = true) -> void:
	if t == null:
		return
	var data := Proto.pack(msg)
	if is_host():
		for pid in _tid:
			t.send(_tid[pid], data, reliable)
	elif my_id != 0:
		t.send(NetTransport.HOST_ID, data, reliable)

## The attacking phone hands over its latest frame every tick; it goes out at SNAP_MS.
func set_frame(data: PackedByteArray) -> void:
	_frame = data

func clear_frame() -> void:
	_frame = PackedByteArray()

## The match is over (both phones): count the win and go back to the lobby state.
## `finished` is the match that ended: a rematch may already have replaced it.
func match_over(finished: MpMatch) -> void:
	if game == null or finished != game:
		return
	if is_host() and game.winner >= 0:
		var pid: int = order[game.winner] if game.winner < order.size() else 0
		if players.has(pid):
			players[pid].wins += 1
	playing = false
	_frame = PackedByteArray()
	if is_host():
		_broadcast_lobby()
	else:
		lobby_changed.emit()

# ================================================================== both
func leave() -> void:
	if t:
		if is_host():
			_broadcast({"t": "bye", "why": "The host closed the room"})
		elif role == "client" and my_id != 0:
			t.send(NetTransport.HOST_ID, Proto.pack({"t": "bye"}))
		t.poll()
		t.scan_stop()
		t.close()
	_reset()

func _reset() -> void:
	t = null
	role = ""
	my_id = 0
	players = {}
	order = []
	playing = false
	game = null
	_pid = {}
	_tid = {}
	_samples = []
	offset_ms = 0.0
	_frame = PackedByteArray()

func _process(_dt: float) -> void:
	if t == null:
		return
	t.poll()
	if t == null:
		return
	var now := Time.get_ticks_msec()
	if role == "client" and my_id != 0 and now >= _next_ping:
		_next_ping = now + (250 if _samples.size() < 8 else 2000)
		t.send(NetTransport.HOST_ID, Proto.pack({"t": "ping", "c": Time.get_ticks_usec() / 1000.0}))
	if role == "host" and now >= _next_ping:
		# keeps an idle online room alive
		_next_ping = now + 2000
		for pid in _tid:
			t.send(_tid[pid], Proto.pack({"t": "tick"}))
	if playing and not _frame.is_empty() and now >= _next_frame:
		_next_frame = now + SNAP_MS
		if is_host():
			for pid in _tid:
				t.send(_tid[pid], _frame, false)
		elif my_id != 0:
			t.send(NetTransport.HOST_ID, _frame, false)
	if playing and game != null:
		game.host_tick()
	_watch_silence(now)
	var gone := []
	for k in rooms:
		if now - int(rooms[k].seen) > 5000:
			gone.append(k)
	for k in gone:
		rooms.erase(k)
	if not gone.is_empty():
		rooms_changed.emit()

## A phone that locks or switches networks can vanish without the link noticing for a long
## time (TCP on the online relay). Silence means gone: the host drops them, a guest leaves.
func _watch_silence(now: int) -> void:
	var linked := (is_host() and not _tid.is_empty()) or (role == "client" and my_id != 0)
	if not linked:
		_last_rx = now
		return
	if now - _last_rx < SILENCE_MS:
		return
	if is_host():
		for pid in _tid.keys():
			_drop_player(pid)
	else:
		var tr := t
		_reset()
		if tr:
			tr.close()
		ended.emit("Lost the other phone")

# ================================================================== transport events
func _on_room(room: Dictionary, tr: NetTransport) -> void:
	if tr != t or role != "":
		return
	room["seen"] = Time.get_ticks_msec()
	var fresh := not rooms.has(room.key)
	var changed: bool = fresh or rooms[room.key].players != room.players
	rooms[room.key] = room
	if changed:
		rooms_changed.emit()

func _on_connected(tr: NetTransport) -> void:
	if tr != t or role != "client":
		return
	t.send(NetTransport.HOST_ID, Proto.pack({"t": "hello", "v": Proto.VERSION, "name": my_name(), "club": my_club(), "cap": Caps.selected()}))

## Online quick match with nobody waiting: the relay made us the host of a new room.
func _on_became_host() -> void:
	if t != online:
		return
	room_name = my_name()
	_become_host()

func _on_connect_failed(reason: String, tr: NetTransport) -> void:
	if tr != t:
		return
	_reset()
	join_failed.emit(reason)

func _on_peer_joined(_tid_in: int, _tr: NetTransport) -> void:
	pass    # wait for "hello"

func _on_peer_left(tid: int, tr: NetTransport) -> void:
	if tr != t or not is_host():
		return
	if _pid.has(tid):
		_drop_player(_pid[tid])

func _on_lost_host(reason: String, tr: NetTransport) -> void:
	if tr != t or role != "client":
		return
	var was_joined := my_id != 0
	_reset()
	if was_joined:
		ended.emit(reason)
	else:
		join_failed.emit(reason)

func _on_host_failed(reason: String, tr: NetTransport) -> void:
	if tr != t:
		return
	t.close()
	_reset()
	ended.emit(reason)

func _on_packet(from: int, data: PackedByteArray, tr: NetTransport) -> void:
	if tr != t:
		return
	_last_rx = Time.get_ticks_msec()
	if Proto.is_play(data):
		if game != null and game.att != game.me:
			var f := Proto.unpack_play(data)
			if not f.is_empty():
				game.remote_frame.emit(f)
		return
	var msg := Proto.unpack(data)
	if msg.is_empty():
		return
	if is_host():
		_host_msg(from, msg)
	else:
		_client_msg(msg)

func _game_msg(side: int, msg: Dictionary) -> void:
	if game == null:
		return
	match String(msg.t):
		"res":
			game.on_result(side, msg)
		"spr":
			game.on_sprint(side, float(msg.get("at", 0.0)))
		"sx":
			game.remote_sprint.emit(float(msg.get("x", 0.0)))
		"pev":
			game.remote_event.emit(msg)
		"kv":
			game.remote_verdict.emit(String(msg.get("outcome", "")), int(msg.get("seq", -1)), int(msg.get("n", -1)))

func _host_msg(tid: int, msg: Dictionary) -> void:
	var pid: int = _pid.get(tid, 0)
	match str(msg.t):
		"hello":
			if pid != 0:
				return
			var why := ""
			if int(msg.get("v", 0)) != Proto.VERSION:
				why = "Different game version: update both phones"
			elif playing:
				why = "A match is on. Try again when it ends"
			elif order.size() >= 2:
				why = "The room is full"
			if why != "":
				t.send(tid, Proto.pack({"t": "reject", "why": why}))
				return
			_add_player(tid, str(msg.get("name", "")))
			var club := int(msg.get("club", players[2].club)) % League.club_count()
			if club == int(players[1].club):
				club = (club + 1) % League.club_count()
			players[2].club = club
			players[2].cap = _known_cap(String(msg.get("cap", "classic")))
			_broadcast_lobby()
		"club":
			if pid != 0 and not playing:
				players[pid].club = int(msg.get("i", 0)) % League.club_count()
				_broadcast_lobby()
		"ping":
			t.send(tid, Proto.pack({"t": "pong", "c": msg.get("c", 0.0), "h": now_ms()}))
		"res", "spr", "sx", "pev", "kv":
			if pid != 0:
				_game_msg(1, msg)
		"bye":
			if pid != 0:
				_drop_player(pid)

func _client_msg(msg: Dictionary) -> void:
	match str(msg.t):
		"welcome":
			_last_rx = Time.get_ticks_msec()
			my_id = int(msg.id)
			room_name = str(msg.get("room", room_name))
			_next_ping = 0
			joined.emit()
		"reject":
			var why := str(msg.get("why", "Could not join"))
			leave()
			join_failed.emit(why)
		"lobby":
			players = {}
			order = []
			for p in msg.get("players", []):
				var pid := int(p.id)
				players[pid] = {"id": pid, "name": str(p.name), "club": int(p.club), "wins": int(p.get("wins", 0)),
					"cap": _known_cap(String(p.get("cap", "classic")))}
				order.append(pid)
			cfg = msg.get("cfg", cfg)
			room_name = str(msg.get("room", room_name))
			lobby_changed.emit()
		"pong":
			var now := Time.get_ticks_usec() / 1000.0
			var rtt: float = now - float(msg.c)
			_samples.append([rtt, float(msg.h) + rtt * 0.5 - now])
			if _samples.size() > 16:
				_samples.pop_front()
			var best: Array = _samples[0]
			for s in _samples:
				if s[0] < best[0]:
					best = s
			offset_ms = best[1]
		"match":
			_begin_match(msg)
		"st":
			if game != null:
				game.apply(msg)
		"res", "spr", "sx", "pev", "kv":
			_game_msg(0, msg)
		"bye":
			var why := str(msg.get("why", "The host left"))
			if t:
				t.close()
			_reset()
			ended.emit(why)
