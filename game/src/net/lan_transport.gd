class_name LanTransport
extends NetTransport
## Wi-Fi link: same network or a phone hotspot. ENet for the session, UDP beacons so joiners
## can find the room. Players can also type the host's address (iOS blocks broadcast discovery
## without a special entitlement).

# not Retro Swim's ports (24770/24771), so the two games never see each other's rooms
const PORT := 24780
const BEACON_PORT := 24781
const BEACON_TAG := "retropolo"
const CONNECT_TIMEOUT := 7.0

var peer: ENetMultiplayerPeer = null
var beacon: PacketPeerUDP = null
var listener: PacketPeerUDP = null
var is_host := false
var room := {"name": "", "players": 1, "max": 2}
var _next_beacon := 0
var _connecting := false
var _connect_start := 0
var _was_connected := false

func kind() -> String:
	return "lan"

func status() -> String:
	return "ready"

func max_players() -> int:
	return 2

## First private IPv4 address (shown in the lobby so friends can type it).
static func local_ip() -> String:
	var best := ""
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
		if best == "":
			best = a
	return best

func host(room_name: String, p_max: int) -> Error:
	close()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, maxi(p_max - 1, 1))
	if err != OK:
		peer = null
		return err
	peer.peer_connected.connect(func(id: int): peer_joined.emit(id))
	peer.peer_disconnected.connect(func(id: int): peer_left.emit(id))
	is_host = true
	room = {"name": room_name, "players": 1, "max": p_max}
	beacon = PacketPeerUDP.new()
	beacon.set_broadcast_enabled(true)
	_next_beacon = 0
	return OK

func set_room_info(players: int) -> void:
	room.players = players

func scan_start() -> void:
	scan_stop()
	listener = PacketPeerUDP.new()
	if listener.bind(BEACON_PORT) != OK:
		listener = null

func scan_stop() -> void:
	if listener:
		listener.close()
		listener = null

func join(r: Dictionary) -> Error:
	close()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(str(r.get("addr", "")), int(r.get("port", PORT)))
	if err != OK:
		peer = null
		return err
	is_host = false
	_connecting = true
	_connect_start = Time.get_ticks_msec()
	_was_connected = false
	return OK

func send(to: int, data: PackedByteArray, reliable: bool = true) -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.set_target_peer(to)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	peer.put_packet(data)

func poll() -> void:
	if peer:
		peer.poll()
		if not is_host:
			_poll_client_state()
		while peer and peer.get_available_packet_count() > 0:
			var from := peer.get_packet_peer()
			var d := peer.get_packet()
			packet.emit(from, d)
	if is_host and beacon and Time.get_ticks_msec() >= _next_beacon:
		_next_beacon = Time.get_ticks_msec() + 1000
		_send_beacon()
	if listener:
		while listener.get_available_packet_count() > 0:
			var d := listener.get_packet()
			var ip := listener.get_packet_ip()
			var info = JSON.parse_string(d.get_string_from_utf8())
			if typeof(info) != TYPE_DICTIONARY or info.get("g", "") != BEACON_TAG:
				continue
			var port := int(info.get("port", PORT))
			room_found.emit({"key": "lan:%s:%d" % [ip, port], "name": Proto.clean_name(str(info.get("n", ""))),
				"players": int(info.get("p", 1)), "max": int(info.get("m", 8)), "v": int(info.get("v", 0)),
				"addr": ip, "port": port})

func _poll_client_state() -> void:
	var st := peer.get_connection_status()
	if _connecting:
		if st == MultiplayerPeer.CONNECTION_CONNECTED:
			_connecting = false
			_was_connected = true
			connected.emit()
		elif st == MultiplayerPeer.CONNECTION_DISCONNECTED or Time.get_ticks_msec() - _connect_start > CONNECT_TIMEOUT * 1000.0:
			_connecting = false
			close()
			connect_failed.emit("Could not reach the host")
	elif _was_connected and st == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_was_connected = false
		close()
		lost_host.emit("Lost the host")

func _send_beacon() -> void:
	var msg := JSON.stringify({"g": BEACON_TAG, "v": Proto.VERSION, "n": room.name, "p": room.players,
		"m": room.max, "port": PORT}).to_utf8_buffer()
	var dests := ["255.255.255.255", "127.0.0.1"]
	for a in IP.get_local_addresses():
		var parts: PackedStringArray = a.split(".")
		if parts.size() == 4 and not a.begins_with("127."):
			dests.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	for d in dests:
		beacon.set_dest_address(d, BEACON_PORT)
		beacon.put_packet(msg)

func close() -> void:
	if peer:
		peer.close()
		peer = null
	if beacon:
		beacon.close()
		beacon = null
	is_host = false
	_connecting = false
	_was_connected = false
