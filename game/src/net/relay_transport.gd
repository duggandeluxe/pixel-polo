class_name RelayTransport
extends NetTransport
## Online link: both phones talk to a small relay server over WebSocket, so it works anywhere
## with internet (no shared Wi-Fi). The host opens a room and gets a 4-letter code; a friend
## types the code. QUICK MATCH pairs you with whoever else is waiting.
##
## Relay protocol (relay/worker.js and src/net/relay_server.gd speak it):
##   text frames, JSON control:
##     -> {op: "host" | "join" | "quick", g, v, name, code?}
##     <- {op: "room", code}          you host this room (also the reply to a quick match with nobody waiting)
##     <- {op: "joined", id, code}    you joined; you are peer `id`, the host is peer 1
##     <- {op: "peer", id, name}      host: someone joined
##     <- {op: "left", id}            host: they left
##     <- {op: "closed", why}         client: the room closed
##     <- {op: "error", why}
##   binary frames: [peer id] + payload. Host -> relay: the target; relay -> host: the sender.

signal room_ready(code: String)
signal became_host                   # a quick match made us the host

const GAME := "retropolo"
const CONNECT_TIMEOUT := 8.0

var ws: WebSocketPeer = null
var url := ""
var code := ""
var is_host := false
var _hello := {}                     # the control message to send once the socket opens
var _open := false
var _start := 0
var _joined := false

func _init(p_url: String = "") -> void:
	url = p_url

func kind() -> String:
	return "online"

func status() -> String:
	return "ready" if url != "" else "unsupported"

func max_players() -> int:
	return 2

func host(room_name: String, _max: int) -> Error:
	return _open_socket({"op": "host", "g": GAME, "v": Proto.VERSION, "name": room_name}, true)

## room: {"code": "K7QX"} or {"quick": true}
func join(room: Dictionary) -> Error:
	if room.get("quick", false):
		return _open_socket({"op": "quick", "g": GAME, "v": Proto.VERSION, "name": String(room.get("name", ""))}, false)
	return _open_socket({"op": "join", "g": GAME, "v": Proto.VERSION, "name": String(room.get("name", "")),
		"code": String(room.get("code", "")).to_upper()}, false)

func _open_socket(hello: Dictionary, as_host: bool) -> Error:
	close()
	if url == "":
		return ERR_UNCONFIGURED
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 1 << 18
	ws.outbound_buffer_size = 1 << 18
	ws.heartbeat_interval = 5.0   # pings keep mobile networks and proxies from dropping a quiet socket
	# the hello rides in the URL too: the Cloudflare relay routes a socket to its room before
	# any message arrives (the Godot relay just reads the JSON hello)
	var q := PackedStringArray()
	for k in hello:
		q.append("%s=%s" % [k, String(str(hello[k])).uri_encode()])
	var base := url
	if base.split("://")[-1].find("/") < 0:
		base += "/"   # "ws://host:port" needs a path before the query
	var err := ws.connect_to_url(base + ("&" if base.contains("?") else "?") + "&".join(q))
	if err != OK:
		ws = null
		return err
	_hello = hello
	is_host = as_host
	_open = false
	_joined = false
	_start = Time.get_ticks_msec()
	return OK

func send(to: int, data: PackedByteArray, _reliable: bool = true) -> void:
	if ws == null or not _open:
		return
	var frame := PackedByteArray([to & 0xff])
	frame.append_array(data)
	ws.send(frame, WebSocketPeer.WRITE_MODE_BINARY)

func poll() -> void:
	if ws == null:
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_CONNECTING:
		if Time.get_ticks_msec() - _start > CONNECT_TIMEOUT * 1000.0:
			_fail("Can't reach the online server")
		return
	if st == WebSocketPeer.STATE_CLOSED or st == WebSocketPeer.STATE_CLOSING:
		if st == WebSocketPeer.STATE_CLOSED:
			# the relay puts its reason ("No room K7QX", "The host left") in the close frame;
			# the text message sent just before may never arrive
			var why := ws.get_close_reason()
			if why == "":
				why = "Lost the online server" if _open else "Can't reach the online server"
			_fail(why)
		return
	if not _open:
		_open = true
		ws.send_text(JSON.stringify(_hello))
	while ws != null and ws.get_available_packet_count() > 0:
		var pkt := ws.get_packet()
		if ws.was_string_packet():
			_control(pkt.get_string_from_utf8())
		elif pkt.size() >= 1:
			packet.emit(int(pkt[0]), pkt.slice(1))

func _control(text: String) -> void:
	var m = JSON.parse_string(text)
	if typeof(m) != TYPE_DICTIONARY:
		return
	match String(m.get("op", "")):
		"room":
			code = String(m.get("code", ""))
			if not is_host:
				is_host = true
				became_host.emit()
			room_ready.emit(code)
		"joined":
			code = String(m.get("code", code))
			_joined = true
			connected.emit()
		"peer":
			peer_joined.emit(int(m.get("id", 0)))
		"left":
			peer_left.emit(int(m.get("id", 0)))
		"closed":
			var why := String(m.get("why", "The room closed"))
			close()
			lost_host.emit(why)
		"error":
			var why := String(m.get("why", "Online error"))
			var was_host := is_host
			close()
			if was_host:
				host_failed.emit(why)
			else:
				connect_failed.emit(why)

func _fail(why: String) -> void:
	var was_host := is_host
	var was_joined := _joined
	close()
	if was_host:
		host_failed.emit(why)
	elif was_joined:
		lost_host.emit(why)
	else:
		connect_failed.emit(why)

func close() -> void:
	if ws != null:
		ws.close()
		ws = null
	_open = false
	_joined = false
	is_host = false
	code = ""
