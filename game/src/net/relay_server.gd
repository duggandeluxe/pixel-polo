class_name RelayServer
extends Node
## The online relay, in Godot: rooms with 4-letter codes, quick-match pairing, and frame
## forwarding between a host and its guest. Same protocol as relay/worker.js (see
## RelayTransport). Used by the tests, and it can be self-hosted:
##   godot --headless --path game -- --relay 24790

const CODE_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"   # no I/L/O/0/1: easy to read out loud
const MAX_ROOM := 2

var server := TCPServer.new()
var conns: Array = []          # [{ws, room, id, name}]
var rooms := {}                # code -> {host: conn, guests: {id: conn}, quick: bool, g, v}
var rng := RandomNumberGenerator.new()

func start(port: int) -> Error:
	rng.randomize()
	var err := server.listen(port)
	if err == OK:
		print("relay listening on %d" % port)
	return err

func _process(_dt: float) -> void:
	while server.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = 1 << 18
		ws.outbound_buffer_size = 1 << 18
		if ws.accept_stream(server.take_connection()) == OK:
			conns.append({"ws": ws, "room": "", "id": 0, "name": ""})
	for c in conns.duplicate():
		var ws: WebSocketPeer = c.ws
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_CLOSED:
			_drop(c)
			conns.erase(c)
			continue
		if st != WebSocketPeer.STATE_OPEN:
			continue
		while ws.get_available_packet_count() > 0:
			var pkt := ws.get_packet()
			if ws.was_string_packet():
				_control(c, pkt.get_string_from_utf8())
			else:
				_forward(c, pkt)

func _send(c: Dictionary, m: Dictionary) -> void:
	(c.ws as WebSocketPeer).send_text(JSON.stringify(m))

func _new_code() -> String:
	while true:
		var s := ""
		for _i in 4:
			s += CODE_CHARS[rng.randi() % CODE_CHARS.length()]
		if not rooms.has(s):
			return s
	return ""

func _control(c: Dictionary, text: String) -> void:
	var m = JSON.parse_string(text)
	if typeof(m) != TYPE_DICTIONARY or c.room != "":
		return
	c.name = String(m.get("name", ""))
	match String(m.get("op", "")):
		"host":
			_open_room(c, m, false)
		"join":
			var code := String(m.get("code", "")).to_upper()
			if not rooms.has(code):
				_send(c, {"op": "error", "why": "No room %s. Check the code." % code})
			elif String(rooms[code].g) != String(m.get("g", "")) or int(rooms[code].v) != int(m.get("v", 0)):
				_send(c, {"op": "error", "why": "Different game version: update both phones"})
			elif rooms[code].guests.size() + 1 >= MAX_ROOM:
				_send(c, {"op": "error", "why": "That room is full"})
			else:
				_join_room(c, code)
		"quick":
			for code in rooms:
				var r: Dictionary = rooms[code]
				if r.quick and r.guests.is_empty() and String(r.g) == String(m.get("g", "")) and int(r.v) == int(m.get("v", 0)):
					_join_room(c, code)
					return
			_open_room(c, m, true)

func _open_room(c: Dictionary, m: Dictionary, quick: bool) -> void:
	var code := _new_code()
	rooms[code] = {"host": c, "guests": {}, "quick": quick, "g": String(m.get("g", "")), "v": int(m.get("v", 0))}
	c.room = code
	c.id = 1
	_send(c, {"op": "room", "code": code})

func _join_room(c: Dictionary, code: String) -> void:
	var r: Dictionary = rooms[code]
	var id := 2
	while r.guests.has(id):
		id += 1
	r.guests[id] = c
	c.room = code
	c.id = id
	_send(c, {"op": "joined", "id": id, "code": code})
	_send(r.host, {"op": "peer", "id": id, "name": c.name})

## [peer] + payload. From the host, peer is the target; to the host, peer is the sender.
func _forward(c: Dictionary, pkt: PackedByteArray) -> void:
	if c.room == "" or pkt.size() < 1 or not rooms.has(c.room):
		return
	var r: Dictionary = rooms[c.room]
	var payload := pkt.slice(1)
	if c.id == 1:
		var to: Dictionary = r.guests.get(int(pkt[0]), {})
		if not to.is_empty():
			var out := PackedByteArray([1])
			out.append_array(payload)
			(to.ws as WebSocketPeer).send(out, WebSocketPeer.WRITE_MODE_BINARY)
	else:
		var out := PackedByteArray([c.id & 0xff])
		out.append_array(payload)
		(r.host.ws as WebSocketPeer).send(out, WebSocketPeer.WRITE_MODE_BINARY)

func _drop(c: Dictionary) -> void:
	if c.room == "" or not rooms.has(c.room):
		return
	var r: Dictionary = rooms[c.room]
	if c.id == 1:
		for id in r.guests:
			var g: Dictionary = r.guests[id]
			_send(g, {"op": "closed", "why": "The host left"})
			g.room = ""
		rooms.erase(c.room)
	else:
		r.guests.erase(c.id)
		_send(r.host, {"op": "left", "id": c.id})
	c.room = ""
